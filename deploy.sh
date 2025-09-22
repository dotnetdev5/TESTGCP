#!/bin/bash

# GCP AI Gateway Deployment Script
# This script deploys the complete AI Gateway architecture on GCP

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local tools=("gcloud" "kubectl" "helm" "docker")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and run the script again."
        exit 1
    fi
    
    print_status "All required tools are installed"
}

# Set up environment variables
setup_environment() {
    print_header "Setting up Environment Variables"
    
    # Check if PROJECT_ID is set
    if [ -z "$PROJECT_ID" ]; then
        print_warning "PROJECT_ID not set. Please enter your GCP Project ID:"
        read -r PROJECT_ID
        export PROJECT_ID
    fi
    
    # Set default values if not provided
    export REGION=${REGION:-"us-central1"}
    export CLUSTER_NAME=${CLUSTER_NAME:-"gateway-cluster"}
    export ZONE=${ZONE:-"us-central1-a"}
    
    print_status "Environment variables set:"
    print_status "  PROJECT_ID: $PROJECT_ID"
    print_status "  REGION: $REGION"
    print_status "  CLUSTER_NAME: $CLUSTER_NAME"
    print_status "  ZONE: $ZONE"
    
    # Set gcloud project
    gcloud config set project $PROJECT_ID
}

# Enable required GCP APIs
enable_apis() {
    print_header "Enabling Required GCP APIs"
    
    local apis=(
        "container.googleapis.com"
        "aiplatform.googleapis.com"
        "cloudbuild.googleapis.com"
        "containerregistry.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
        "compute.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_status "Enabling $api..."
        gcloud services enable $api
    done
    
    print_status "All APIs enabled successfully"
}

# Create GKE cluster
create_cluster() {
    print_header "Creating GKE Cluster"
    
    # Check if cluster already exists
    if gcloud container clusters describe $CLUSTER_NAME --region=$REGION &> /dev/null; then
        print_warning "Cluster $CLUSTER_NAME already exists. Skipping creation."
        return
    fi
    
    print_status "Creating GKE cluster: $CLUSTER_NAME"
    gcloud container clusters create $CLUSTER_NAME \
        --region=$REGION \
        --num-nodes=3 \
        --enable-autoscaling \
        --min-nodes=1 \
        --max-nodes=10 \
        --machine-type=e2-standard-4 \
        --enable-autorepair \
        --enable-autoupgrade \
        --enable-ip-alias \
        --enable-network-policy \
        --disk-size=50GB \
        --disk-type=pd-standard \
        --enable-cloud-logging \
        --enable-cloud-monitoring \
        --addons=HorizontalPodAutoscaling,HttpLoadBalancing
    
    print_status "Cluster created successfully"
    
    # Get cluster credentials
    print_status "Getting cluster credentials..."
    gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
}

# Create service accounts
create_service_accounts() {
    print_header "Creating Service Accounts"
    
    # Backend service account
    if ! gcloud iam service-accounts describe backend-service@$PROJECT_ID.iam.gserviceaccount.com &> /dev/null; then
        print_status "Creating backend service account..."
        gcloud iam service-accounts create backend-service \
            --display-name="Backend Service Account" \
            --description="Service account for backend service"
        
        # Grant necessary permissions
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:backend-service@$PROJECT_ID.iam.gserviceaccount.com" \
            --role="roles/aiplatform.user"
    else
        print_warning "Backend service account already exists"
    fi
    
    # LiteLLM service account
    if ! gcloud iam service-accounts describe litellm@$PROJECT_ID.iam.gserviceaccount.com &> /dev/null; then
        print_status "Creating LiteLLM service account..."
        gcloud iam service-accounts create litellm \
            --display-name="LiteLLM Service Account" \
            --description="Service account for LiteLLM"
        
        # Grant necessary permissions
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:litellm@$PROJECT_ID.iam.gserviceaccount.com" \
            --role="roles/aiplatform.user"
    else
        print_warning "LiteLLM service account already exists"
    fi
    
    # Create service account keys
    print_status "Creating service account keys..."
    gcloud iam service-accounts keys create backend-service-key.json \
        --iam-account=backend-service@$PROJECT_ID.iam.gserviceaccount.com
    
    gcloud iam service-accounts keys create litellm-key.json \
        --iam-account=litellm@$PROJECT_ID.iam.gserviceaccount.com
    
    # Create Kubernetes secrets
    kubectl create secret generic google-cloud-key \
        --from-file=key.json=backend-service-key.json \
        --dry-run=client -o yaml | kubectl apply -f -
}

# Deploy Kong Gateway
deploy_kong() {
    print_header "Deploying Kong Gateway"
    
    # Add Kong Helm repository
    helm repo add kong https://charts.konghq.com
    helm repo update
    
    # Create Kong namespace
    kubectl create namespace kong --dry-run=client -o yaml | kubectl apply -f -
    
    # Update PROJECT_ID in kong-values.yaml
    sed -i "s/PROJECT_ID/$PROJECT_ID/g" configs/kong-values.yaml
    
    # Deploy Kong
    print_status "Installing Kong Gateway..."
    helm upgrade --install kong kong/kong \
        --namespace kong \
        --values configs/kong-values.yaml \
        --wait \
        --timeout=10m
    
    print_status "Kong Gateway deployed successfully"
}

# Build and deploy backend service
deploy_backend_service() {
    print_header "Deploying Backend Service"
    
    # Build Docker image
    print_status "Building backend service Docker image..."
    docker build -t gcr.io/$PROJECT_ID/backend-service:latest ./backend-service
    
    # Push to Container Registry
    print_status "Pushing image to Container Registry..."
    docker push gcr.io/$PROJECT_ID/backend-service:latest
    
    # Update PROJECT_ID in deployment file
    sed -i "s/PROJECT_ID/$PROJECT_ID/g" configs/backend-service-deployment.yaml
    
    # Deploy to Kubernetes
    print_status "Deploying backend service to Kubernetes..."
    kubectl apply -f configs/backend-service-deployment.yaml
    
    print_status "Backend service deployed successfully"
}

# Deploy LiteLLM
deploy_litellm() {
    print_header "Deploying LiteLLM"
    
    # Update PROJECT_ID in deployment file
    sed -i "s/PROJECT_ID/$PROJECT_ID/g" configs/litellm-deployment.yaml
    
    # Deploy LiteLLM
    print_status "Deploying LiteLLM..."
    kubectl apply -f configs/litellm-deployment.yaml
    
    print_status "LiteLLM deployed successfully"
}

# Configure Kong plugins
configure_kong_plugins() {
    print_header "Configuring Kong Plugins"
    
    # Wait for Kong to be ready
    print_status "Waiting for Kong to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n kong --timeout=300s
    
    # Apply Kong plugins
    print_status "Applying Kong plugins..."
    kubectl apply -f configs/kong-plugins.yaml
    
    print_status "Kong plugins configured successfully"
}

# Setup monitoring
setup_monitoring() {
    print_header "Setting up Monitoring"
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install Prometheus
    print_status "Installing Prometheus..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set grafana.adminPassword=admin123 \
        --wait
    
    print_status "Monitoring setup completed"
}

# Get service information
get_service_info() {
    print_header "Getting Service Information"
    
    print_status "Waiting for LoadBalancer IP..."
    sleep 30
    
    # Get Kong Gateway external IP
    KONG_IP=$(kubectl get service kong-kong-proxy -n kong -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$KONG_IP" ]; then
        print_warning "LoadBalancer IP not yet assigned. Please check later with:"
        print_warning "kubectl get service kong-kong-proxy -n kong"
    else
        print_status "Kong Gateway External IP: $KONG_IP"
    fi
    
    # Get service status
    print_status "Service Status:"
    kubectl get pods -A
    
    print_status "Services:"
    kubectl get services -A
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f backend-service-key.json litellm-key.json
}

# Main deployment function
main() {
    print_header "Starting GCP AI Gateway Deployment"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    check_prerequisites
    setup_environment
    enable_apis
    create_cluster
    create_service_accounts
    deploy_kong
    deploy_backend_service
    deploy_litellm
    configure_kong_plugins
    setup_monitoring
    get_service_info
    
    print_header "Deployment Completed Successfully!"
    print_status "Your AI Gateway is now ready to use."
    
    if [ ! -z "$KONG_IP" ]; then
        print_status "Gateway URL: http://$KONG_IP"
        print_status "Test endpoint: http://$KONG_IP/api/v1/health"
    fi
    
    print_status "Next steps:"
    print_status "1. Configure your domain DNS to point to the LoadBalancer IP"
    print_status "2. Update TLS certificates in configs/kong-plugins.yaml"
    print_status "3. Configure authentication and rate limiting as needed"
    print_status "4. Test the complete flow with sample requests"
}

# Run main function
main "$@"
