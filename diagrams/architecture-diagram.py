"""
Architecture Diagram Generator for GCP AI Gateway
This script generates architecture diagrams using the diagrams library
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.gcp.compute import GKE, ComputeEngine
from diagrams.gcp.network import LoadBalancing, DNS, VPC
from diagrams.gcp.storage import Storage
from diagrams.gcp.database import SQL
from diagrams.gcp.analytics import BigQuery
from diagrams.gcp.ml import AIHub, AutoML
from diagrams.onprem.client import Users, Client
from diagrams.onprem.container import Docker
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.onprem.network import Kong
from diagrams.programming.framework import FastAPI
from diagrams.programming.language import Python

def create_architecture_diagram():
    """Create the main architecture diagram"""
    
    with Diagram("GCP AI Gateway Architecture", show=False, direction="TB", filename="architecture"):
        # Users
        users = Users("Users/Clients")
        
        with Cluster("Internet"):
            dns = DNS("DNS")
            
        with Cluster("Google Cloud Platform"):
            with Cluster("GKE Cluster"):
                # Load Balancer
                lb = LoadBalancing("Load Balancer")
                
                with Cluster("Kong Gateway"):
                    kong = Kong("Kong API Gateway")
                    kong_plugins = [
                        "Rate Limiting",
                        "Authentication", 
                        "CORS",
                        "Monitoring"
                    ]
                
                with Cluster("Backend Services"):
                    backend = FastAPI("Backend Service")
                    
                with Cluster("LiteLLM"):
                    litellm = Python("LiteLLM Gateway")
                    
                with Cluster("Monitoring"):
                    prometheus = Prometheus("Prometheus")
                    grafana = Grafana("Grafana")
                
                with Cluster("Storage"):
                    postgres = SQL("PostgreSQL")
                    redis = Storage("Redis Cache")
            
            with Cluster("Vertex AI"):
                vertex_ai = AIHub("Vertex AI Models")
                automl = AutoML("Custom Models")
        
        # Connections
        users >> dns >> lb >> kong
        kong >> backend
        backend >> litellm
        litellm >> vertex_ai
        litellm >> automl
        
        # Monitoring connections
        kong >> prometheus
        backend >> prometheus
        litellm >> prometheus
        prometheus >> grafana
        
        # Storage connections
        kong >> postgres
        litellm >> redis

def create_data_flow_diagram():
    """Create data flow diagram"""
    
    with Diagram("Data Flow Diagram", show=False, direction="LR", filename="data-flow"):
        # External
        user = Client("User")
        
        with Cluster("API Gateway Layer"):
            kong = Kong("Kong Gateway")
            
        with Cluster("Business Logic Layer"):
            backend = FastAPI("Backend Service")
            
        with Cluster("AI Processing Layer"):
            litellm = Python("LiteLLM")
            
        with Cluster("AI Models"):
            vertex = AIHub("Vertex AI")
        
        # Data flow
        user >> Edge(label="1. API Request") >> kong
        kong >> Edge(label="2. Route & Validate") >> backend
        backend >> Edge(label="3. Process & Forward") >> litellm
        litellm >> Edge(label="4. Model Request") >> vertex
        vertex >> Edge(label="5. AI Response") >> litellm
        litellm >> Edge(label="6. Formatted Response") >> backend
        backend >> Edge(label="7. Business Logic") >> kong
        kong >> Edge(label="8. Final Response") >> user

def create_deployment_diagram():
    """Create deployment diagram"""
    
    with Diagram("Deployment Architecture", show=False, direction="TB", filename="deployment"):
        with Cluster("Development"):
            dev_docker = Docker("Docker Build")
            
        with Cluster("CI/CD"):
            build = ComputeEngine("Cloud Build")
            
        with Cluster("Container Registry"):
            registry = Storage("Container Registry")
            
        with Cluster("GKE Production"):
            with Cluster("Kong Namespace"):
                kong_pods = [Kong("Kong Pod 1"), Kong("Kong Pod 2")]
                
            with Cluster("Default Namespace"):
                backend_pods = [FastAPI("Backend Pod 1"), FastAPI("Backend Pod 2"), FastAPI("Backend Pod 3")]
                litellm_pods = [Python("LiteLLM Pod 1"), Python("LiteLLM Pod 2")]
                
            with Cluster("Monitoring Namespace"):
                monitoring = [Prometheus("Prometheus"), Grafana("Grafana")]
        
        # Deployment flow
        dev_docker >> build >> registry
        registry >> kong_pods
        registry >> backend_pods
        registry >> litellm_pods

if __name__ == "__main__":
    print("Generating architecture diagrams...")
    create_architecture_diagram()
    create_data_flow_diagram()
    create_deployment_diagram()
    print("Diagrams generated successfully!")
    print("Files created:")
    print("- architecture.png")
    print("- data-flow.png") 
    print("- deployment.png")
