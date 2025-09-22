# 🚀 GCP AI Gateway - Complete Implementation Guide

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GCP](https://img.shields.io/badge/Google%20Cloud-4285F4?logo=google-cloud&logoColor=white)](https://cloud.google.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Kong](https://img.shields.io/badge/Kong-003459?logo=kong&logoColor=white)](https://konghq.com/)

## 📋 Overview

This repository contains a complete, production-ready implementation of an AI Gateway architecture on Google Cloud Platform (GCP). The gateway provides a unified interface for AI model access through Kong Gateway, LiteLLM, and Vertex AI integration.

### 🏗️ Architecture Components

- **Kong Gateway**: API Gateway with rate limiting, authentication, and policy enforcement
- **Backend Service**: FastAPI-based business logic layer
- **LiteLLM**: Unified AI model management and routing
- **Vertex AI**: Google Cloud's AI platform integration
- **GKE**: Scalable Kubernetes deployment
- **Monitoring**: Prometheus and Grafana for observability

## 🎯 Key Features

✅ **Centralized API Management**: Single entry point for all AI requests  
✅ **Multi-Model Support**: OpenAI, Anthropic, Vertex AI, and more  
✅ **Rate Limiting & Security**: Built-in protection and authentication  
✅ **Auto-Scaling**: Kubernetes-based horizontal scaling  
✅ **Monitoring & Observability**: Complete metrics and logging  
✅ **Production Ready**: Security, reliability, and performance optimized  

## 🚀 Quick Start

### Prerequisites

- Google Cloud Project with billing enabled
- `gcloud` CLI installed and configured
- `kubectl` installed
- `helm` installed
- Docker installed

### One-Command Deployment

```bash
# Clone the repository
git clone <repository-url>
cd gcp-ai-gateway

# Set your project ID
export PROJECT_ID="your-gcp-project-id"

# Run the deployment script
chmod +x deploy.sh
./deploy.sh
```

### Manual Deployment

If you prefer step-by-step deployment, follow the detailed guide in [GCP-Gateway-Architecture-Guide.md](./GCP-Gateway-Architecture-Guide.md).

## 📁 Repository Structure

```
├── 📄 GCP-Gateway-Architecture-Guide.md    # Complete implementation guide
├── 🚀 deploy.sh                            # One-click deployment script
├── 📁 configs/                             # Kubernetes configurations
│   ├── kong-values.yaml                    # Kong Gateway configuration
│   ├── backend-service-deployment.yaml     # Backend service deployment
│   ├── litellm-deployment.yaml            # LiteLLM deployment
│   └── kong-plugins.yaml                  # Kong plugins configuration
├── 📁 backend-service/                     # Backend service code
│   ├── main.py                            # FastAPI application
│   ├── requirements.txt                   # Python dependencies
│   └── Dockerfile                         # Container configuration
├── 📁 diagrams/                           # Architecture diagrams
│   └── architecture-diagram.py           # Diagram generation script
├── 📁 testing/                            # Testing utilities
│   └── test-requests.sh                  # Comprehensive test suite
└── 📄 README.md                          # This file
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PROJECT_ID` | GCP Project ID | Required |
| `REGION` | GCP Region | `us-central1` |
| `CLUSTER_NAME` | GKE Cluster Name | `gateway-cluster` |

### Kong Gateway Configuration

The Kong Gateway is configured with the following plugins:
- Rate Limiting (100/min, 1000/hour, 10000/day)
- JWT Authentication
- CORS Support
- Request/Response Transformation
- Prometheus Metrics

### LiteLLM Configuration

Supports multiple AI models:
- **Vertex AI**: Gemini Pro, Text Bison, Chat Bison
- **OpenAI**: GPT-3.5 Turbo, GPT-4 (with API key)
- **Fallback Support**: Automatic model fallbacks

## 🧪 Testing

### Automated Testing

```bash
# Run the complete test suite
chmod +x testing/test-requests.sh
export GATEWAY_URL="http://your-gateway-ip"
export API_KEY="your-api-key"
./testing/test-requests.sh
```

### Manual Testing

```bash
# Health check
curl http://your-gateway-ip/health

# Chat request
curl -X POST http://your-gateway-ip/api/v1/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "message": "Hello, how can you help me?",
    "model": "gemini-pro",
    "temperature": 0.7,
    "max_tokens": 1000
  }'
```

## 📊 Monitoring

### Prometheus Metrics

The gateway exposes comprehensive metrics:
- Request counts and durations
- Model usage statistics
- Error rates and types
- Resource utilization

### Grafana Dashboards

Access Grafana at `http://your-gateway-ip:3000` (admin/admin123)

### Health Checks

- **Health**: `/health` - Overall system health
- **Readiness**: `/ready` - Service readiness
- **Metrics**: `/metrics` - Prometheus metrics

## 🔒 Security

### Authentication

- JWT-based authentication through Kong
- Service-to-service authentication with GCP service accounts
- API key management for external access

### Network Security

- Private GKE cluster option
- Network policies for pod-to-pod communication
- TLS encryption in transit

### Data Protection

- Secrets management with Kubernetes secrets
- No sensitive data in logs
- API key rotation support

## 📈 Scaling

### Horizontal Pod Autoscaling

All services are configured with HPA:
- **Kong**: 2-10 replicas (70% CPU threshold)
- **Backend Service**: 2-20 replicas (70% CPU, 80% memory)
- **LiteLLM**: 2-10 replicas (70% CPU threshold)

### Cluster Autoscaling

GKE cluster auto-scales from 1-10 nodes based on demand.

## 🛠️ Troubleshooting

### Common Issues

1. **Kong Gateway not accessible**
   ```bash
   kubectl get svc -n kong
   kubectl describe svc kong-kong-proxy -n kong
   ```

2. **Backend service connection issues**
   ```bash
   kubectl get pods
   kubectl logs -l app=backend-service
   ```

3. **LiteLLM model errors**
   ```bash
   kubectl logs -l app=litellm
   kubectl describe configmap litellm-config
   ```

### Debug Commands

```bash
# Check all pods status
kubectl get pods -A

# Check service endpoints
kubectl get endpoints

# View logs
kubectl logs -f deployment/backend-service
kubectl logs -f deployment/litellm -n default

# Check Kong configuration
kubectl exec -it deployment/kong-kong -n kong -- kong config
```

## 💰 Cost Optimization

### Resource Optimization

- Appropriate resource requests and limits
- Preemptible nodes for non-critical workloads
- Cluster autoscaling to minimize idle resources

### Model Cost Management

- LiteLLM cost tracking and budgets
- Model fallbacks to optimize costs
- Request caching to reduce API calls

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
name: Deploy AI Gateway
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Deploy to GCP
      run: ./deploy.sh
      env:
        PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
```

### Cloud Build

```yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/backend-service', './backend-service']
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', 'gcr.io/$PROJECT_ID/backend-service']
- name: 'gcr.io/cloud-builders/kubectl'
  args: ['apply', '-f', 'configs/']
```

## 📚 Additional Resources

- [Kong Gateway Documentation](https://docs.konghq.com/)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Complete Implementation Guide](./GCP-Gateway-Architecture-Guide.md)
- **Issues**: Create an issue in this repository
- **Discussions**: Use GitHub Discussions for questions

---

**Built with ❤️ for the AI community**

*This implementation provides a solid foundation for building scalable AI gateways on GCP. Customize it according to your specific requirements and use cases.*

