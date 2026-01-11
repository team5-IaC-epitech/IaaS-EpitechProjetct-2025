#!/bin/bash

# ============================================================================
# Script de Test de Scalabilité GKE
# ============================================================================
#
# Ce script teste l'autoscaling horizontal (HPA) de votre cluster GKE
# en générant une charge contrôlée et en monitorant la création de pods.
#
# USAGE:
#   ./test-scalability.sh                    # Test interactif par défaut
#   REQUESTS=15000 CONCURRENCY=80 DURATION=300 ./test-scalability.sh
#
# EXEMPLES:
#
#   Test léger (1-2 pods attendus):
#     REQUESTS=5000 CONCURRENCY=20 DURATION=120 ./test-scalability.sh
#
#   Test moyen (3-5 pods attendus):
#     REQUESTS=10000 CONCURRENCY=50 DURATION=300 ./test-scalability.sh
#
#   Test intensif (6-10 pods attendus):
#     REQUESTS=20000 CONCURRENCY=100 DURATION=600 ./test-scalability.sh
#
# VARIABLES D'ENVIRONNEMENT:
#   INGRESS_IP     - IP du load balancer (défaut: 136.110.213.157)
#   ENDPOINT       - Endpoint à tester (défaut: /healthz)
#   REQUESTS       - Nombre total de requêtes (défaut: 10000)
#   CONCURRENCY    - Requêtes simultanées (défaut: 50)
#   DURATION       - Durée du test en secondes (défaut: 300)
#
# PRÉREQUIS:
#   - kubectl configuré et connecté au cluster
#   - Accès au cluster GKE: gcloud container clusters get-credentials ...
#   - L'outil 'hey' sera installé automatiquement si nécessaire
#
# MONITORING EN PARALLÈLE:
#   Dans un autre terminal, lancez:
#     watch -n 2 'kubectl get hpa,pods -l app.kubernetes.io/name=task-manager'
#
# RÉSULTATS ATTENDUS:
#   - Pods scale automatiquement de 1 → N selon la charge
#   - HPA réagit quand CPU > 70% ou Memory > 70%
#   - Performance stable avec temps de réponse < 100ms (p95)
#   - Après le test, scale-down automatique après ~5 minutes
#
# ============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INGRESS_IP="${INGRESS_IP:-136.110.213.157}"
ENDPOINT="${ENDPOINT:-/healthz}"
DEPLOYMENT_NAME="task-manager"
NAMESPACE="default"

# Paramètres de test (modifiables via variables d'environnement)
REQUESTS="${REQUESTS:-10000}"        # Nombre total de requêtes
CONCURRENCY="${CONCURRENCY:-50}"     # Requêtes simultanées
DURATION="${DURATION:-300}"          # Durée du test en secondes (5min par défaut)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test de Scalabilité GKE - Task Manager${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Fonction pour afficher l'état du cluster
show_cluster_state() {
    echo -e "${YELLOW}État actuel du cluster:${NC}"
    kubectl get pods -l app.kubernetes.io/name=task-manager -o wide
    echo ""
    kubectl get hpa task-manager 2>/dev/null || echo "HPA non trouvé"
    echo ""
}

# Fonction pour installer l'outil de load testing
install_load_tool() {
    if ! command -v hey &> /dev/null; then
        echo -e "${YELLOW}Installation de 'hey' (outil de load testing)...${NC}"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install hey
            else
                echo -e "${RED}Homebrew non installé. Installation manuelle...${NC}"
                curl -sL https://github.com/rakyll/hey/releases/download/v0.1.4/hey_darwin_amd64 -o /tmp/hey
                chmod +x /tmp/hey
                sudo mv /tmp/hey /usr/local/bin/hey
            fi
        else
            # Linux
            curl -sL https://github.com/rakyll/hey/releases/download/v0.1.4/hey_linux_amd64 -o /tmp/hey
            chmod +x /tmp/hey
            sudo mv /tmp/hey /usr/local/bin/hey
        fi

        echo -e "${GREEN}✓ 'hey' installé avec succès${NC}"
        echo ""
    fi
}

# Fonction de monitoring en temps réel
monitor_scaling() {
    echo -e "${BLUE}Monitoring de l'autoscaling (Ctrl+C pour arrêter)...${NC}"
    echo ""

    local start_time=$(date +%s)
    local max_pods=0

    while true; do
        clear
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Monitoring - ${elapsed}s écoulées${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""

        # Afficher les pods
        echo -e "${YELLOW}Pods actifs:${NC}"
        local pod_count=$(kubectl get pods -l app.kubernetes.io/name=task-manager -o json | jq '[.items[] | select(.status.phase=="Running")] | length')
        kubectl get pods -l app.kubernetes.io/name=task-manager -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.containerStatuses[0].ready,\
CPU:.spec.containers[0].resources.requests.cpu,\
MEMORY:.spec.containers[0].resources.requests.memory,\
NODE:.spec.nodeName

        echo ""
        echo -e "${GREEN}Nombre de pods Running: $pod_count${NC}"

        if [ "$pod_count" -gt "$max_pods" ]; then
            max_pods=$pod_count
        fi
        echo -e "${GREEN}Maximum de pods atteint: $max_pods${NC}"

        echo ""

        # Afficher HPA
        echo -e "${YELLOW}Horizontal Pod Autoscaler:${NC}"
        kubectl get hpa task-manager 2>/dev/null || echo "HPA non disponible"

        echo ""

        # Afficher les métriques
        echo -e "${YELLOW}Métriques des pods:${NC}"
        kubectl top pods -l app.kubernetes.io/name=task-manager 2>/dev/null || echo "Métriques non disponibles (attendez ~30s après le démarrage)"

        sleep 5
    done
}

# Fonction de test de charge
run_load_test() {
    local url="http://${INGRESS_IP}${ENDPOINT}"

    echo -e "${YELLOW}Configuration du test:${NC}"
    echo "  URL: $url"
    echo "  Requêtes totales: $REQUESTS"
    echo "  Concurrence: $CONCURRENCY"
    echo "  Durée: ${DURATION}s"
    echo ""

    echo -e "${YELLOW}Démarrage du test de charge...${NC}"
    echo ""

    # Lancer le test avec hey
    hey -n "$REQUESTS" -c "$CONCURRENCY" -z "${DURATION}s" "$url" > /tmp/load_test_results.txt 2>&1

    echo -e "${GREEN}✓ Test de charge terminé${NC}"
    echo ""

    # Afficher les résultats
    cat /tmp/load_test_results.txt
}

# Fonction principale
main() {
    echo -e "${YELLOW}1. Vérification de l'accès au cluster...${NC}"
    if ! kubectl get pods &> /dev/null; then
        echo -e "${RED}✗ Impossible d'accéder au cluster Kubernetes${NC}"
        echo "Exécutez: gcloud container clusters get-credentials team5-gke-cluster --region europe-west9 --project iaasepitech"
        exit 1
    fi
    echo -e "${GREEN}✓ Cluster accessible${NC}"
    echo ""

    echo -e "${YELLOW}2. État initial du cluster:${NC}"
    show_cluster_state

    echo -e "${YELLOW}3. Vérification de l'accès à l'API...${NC}"
    if curl -s -f "http://${INGRESS_IP}${ENDPOINT}" > /dev/null; then
        echo -e "${GREEN}✓ API accessible sur http://${INGRESS_IP}${ENDPOINT}${NC}"
    else
        echo -e "${RED}✗ API non accessible. Vérifiez l'IP: ${INGRESS_IP}${NC}"
        exit 1
    fi
    echo ""

    # Installer l'outil de test
    install_load_tool

    # Proposer le choix
    echo -e "${BLUE}Choisissez une option:${NC}"
    echo "  1) Lancer le test de charge ET le monitoring (recommandé)"
    echo "  2) Lancer seulement le monitoring"
    echo "  3) Lancer seulement le test de charge"
    echo ""
    read -p "Votre choix (1-3): " choice

    case $choice in
        1)
            # Lancer le monitoring en arrière-plan dans un nouveau terminal
            echo -e "${YELLOW}Ouverture du monitoring dans un nouveau terminal...${NC}"

            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS - ouvrir dans un nouveau terminal
                osascript -e "tell app \"Terminal\" to do script \"cd $(pwd) && bash $0 monitor\""
            else
                # Linux - essayer gnome-terminal ou xterm
                if command -v gnome-terminal &> /dev/null; then
                    gnome-terminal -- bash -c "$0 monitor; exec bash"
                elif command -v xterm &> /dev/null; then
                    xterm -e "$0 monitor" &
                else
                    echo -e "${YELLOW}Impossible d'ouvrir un nouveau terminal automatiquement.${NC}"
                    echo "Exécutez manuellement dans un autre terminal: $0 monitor"
                fi
            fi

            sleep 3
            run_load_test
            ;;
        2)
            monitor_scaling
            ;;
        3)
            run_load_test
            ;;
        *)
            echo -e "${RED}Choix invalide${NC}"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Test terminé!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}État final du cluster:${NC}"
    show_cluster_state
}

# Point d'entrée
if [ "$1" = "monitor" ]; then
    monitor_scaling
else
    main
fi
