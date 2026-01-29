{
  description = "DeMoD Agent System - Distributed AI Agent Management Platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    poetry2nix.url = "github:nix-community/poetry2nix";
    
    # Cloud provider inputs
    terraform.url = "github:hashicorp/terraform";
    kubernetes.url = "github:kubernetes/kubernetes";
    
    # Development tool inputs
    uv.url = "github:astral-sh/uv";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    devshell.url = "github:numtide/devshell";
  };

  outputs = {
    self, nixpkgs, flake-utils, agenix, poetry2nix, terraform, kubernetes, uv, 
    pre-commit-hooks, devshell
    } @ {
    
    # ========================================
    # System Packages
    # ========================================
    
    packages.x86_64-linux = {
      # Core application
      agent-system = let
        pythonEnv = (nixpkgs.python311.withPackages (ps: [
          ps.fastapi
          ps.uvicorn
          ps.aiohttp
          ps.websockets
          ps.pydantic
          ps.pyjwt
          ps.python-multipart
          ps.redis
          ps.psycopg2-binary
          ps.sqlalchemy
          ps.alembic
          ps.asyncpg
        ]));
        
        poetryEnv = poetry2nix.mkPoetryEnv {
          projectDir = ./.;
        };
        
        # Development shell
        devShell = nixpkgs.mkShell {
          buildInputs = with nixpkgs; [
            # Python development
            python311
            uv
            poetry
            black
            ruff
            mypy
            pytest
            pytest-asyncio
            
            # Infrastructure
            terraform
            kubectl
            docker
            docker-compose
            
            # Documentation
            mkdocs
            mkdocs-material
            
            # Code quality
            pre-commit
            shellcheck
            
            # Utilities
            jq
            curl
            git
            vim
          ];
          
          shellHook = ''
          ''
          # Set environment variables
          ''
          '';
          
          # Development environment setup
          ''
          ''
        '';

        # Docker image
        dockerImage = nixpkgs.dockerTools.buildImage {
          name = "demod-agent-system";
          
          config = {
            Cmd = [ "python", "-m", "uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000" ];
            WorkingDir = "/app";
            ExposedPorts = [ "8000" ];
            Env = [
              "PYTHONPATH=/app/src",
              "AGENT_ENV=production"
            ];
            Volumes = [ "/app/logs" ];
          };
          
          # Multi-stage build
          dockerImage = nixpkgs.dockerTools.buildImage {
            name = "demod-agent-system";
            tag = "latest";
            
            fromImage = "python:3.11-slim";
            
            # Build stage
            copyToRoot = false;
            copyTo = "/app";
            
            # Install dependencies
            run = ''
              # Install system dependencies
              RUN apt-get update && apt-get install -y \\
                build-essential \\
                curl \\
                && rm -rf /var/lib/apt/lists/*;
              
              # Copy requirements
              COPY requirements.txt .
              RUN pip install --no-cache-dir -r requirements.txt;
            '';
            
            # Production stage
            config = {
              Cmd = [ "gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "src.api.main:app" ];
              WorkingDir = "/app";
              ExposedPorts = [ "8000" ];
              Env = [
                "FLASK_ENV=production",
                "PYTHONPATH=/app/src"
              ];
            };
            
            # Final stage
            fromImage = "demod-agent-system-build";
            copyToRoot = false;
            copyTo = "/app";
          };
        };

        # Kubernetes manifests
        kubernetesManifests = {
          deployment = {
            apiVersion = "apps/v1";
            kind = "Deployment";
            metadata = {
              name = "demod-agent-system";
              labels = {
                app = "demod-agent-system";
              };
            };
            
            spec = {
              replicas = 3;
              selector = {
                matchLabels = {
                  app = "demod-agent-system";
                };
              };
              
              template = {
                metadata = {
                  labels = {
                    app = "demod-agent-system";
                  };
                };
                
                spec = {
                  containers = [{
                    name = "demod-agent-system";
                    image = "demod-agent-system:latest";
                    ports = [{
                      containerPort = 8000;
                      protocol = "TCP";
                    }];
                    
                    env = [
                      {
                        name = "FLASK_ENV";
                        value = "production";
                      },
                      {
                        name = "PYTHONPATH";
                        value = "/app/src";
                      }
                    ];
                    
                    resources = {
                      requests = {
                        memory = "512Mi";
                        cpu = "250m";
                      };
                      limits = {
                        memory = "1Gi";
                        cpu = "500m";
                      };
                    }];
                  }];
                };
              };
            };
            
          service = {
            apiVersion = "v1";
            kind = "Service";
            metadata = {
              name = "demod-agent-system";
              labels = {
                app = "demod-agent-system";
              };
            };
            
            spec = {
              selector = {
                app = "demod-agent-system";
              };
              
              ports = [{
                port = 80;
                targetPort = 8000;
                protocol = "TCP";
                name = "http";
              }];
              
              type = "ClusterIP";
            };
          };
        };

        in devShell dockerImage;
      };

      # Terraform configurations
      terraformConfigs = {
        aws = let
          # AWS provider configuration
          awsProvider = {
            source = "hashicorp/aws";
            version = "~> 5.0";
            region = "us-west-2";
          };
          
          # AWS ECS configuration
          ecsCluster = {
            source = "hashicorp/ecs";
            version = "~> 5.0";
            name = "demod-agent-cluster";
            
            setting = {
              name = "demod-agent-cluster";
            capacity_providers = ["FARGATE"];
              default_capacity_provider = "FARGATE";
              fargate_capacity_providers = {
                FARGATE = {
                  default_capacity_provider_strategy = "BEST_FIT_PROGRESSIVE";
                };
              };
            };
          };
          
          awsEcsService = {
            source = "hashicorp/aws";
            version = "~> 5.0";
            name = "demod-agent-service";
            cluster = "demod-agent-cluster";
            launch_type = "FARGATE";
            
            desired_count = 3;
            network_configuration = {
              subnets = ["subnet-private", "subnet-public"];
              security_groups = ["sg-demod-agent"];
            };
            
            task_definition = {
              cpu = "256";
              memory = "512";
              network_mode = "awsvpc";
              
              container_definitions = [{
                name = "demod-agent-system";
                image = "demod-agent-system:latest";
                essential = true;
                
                port_mappings = [{
                  container_port = 8000;
                  host_port = 8000;
                  protocol = "tcp";
                }];
                
                environment = [
                  {
                    name = "FLASK_ENV";
                    value = "production";
                  }
                ];
                
                log_configuration = {
                  log_driver = "awslogs";
                  options = {
                    awslogs-group = "/ecs/demod-agent-system";
                    awslogs-region = "us-west-2";
                    awslogs-stream-prefix = "ecs";
                  };
                };
              }];
            };
          };
          
          # AWS RDS for PostgreSQL
          rdsInstance = {
            source = "hashicorp/aws";
            version = "~> 5.0";
            identifier = "demod-agent-db";
            engine = "postgres";
            engine_version = "15.3";
            instance_class = "db.t3.micro";
            allocated_storage = 20;
            storage_type = "gp2";
            storage_encrypted = true;
            db_name = "demod_agent_system";
            username = "agent";
            password = "changeme123"; # In production, use secrets management
          };
          
          # AWS ElastiCache for Redis
          elasticache_subnet_group = {
            source = "hashicorp/aws";
            version = "~> 5.0";
            name = "demod-agent-cache";
            subnet_ids = ["subnet-private"];
          };
          
          elasticache_subnet = {
            source = "hashicorp/aws";
            version = "~> 5.0";
            subnet_id = "subnet-private";
            cidr = "10.0.1.0/24";
          };
          
          elasticache_cluster = {
            source = "hashicorp/aws";
            version = "~> 5.0";
            node_type = "cache.t3.micro";
            num_cache_nodes = 1;
            parameter_group_name = "default.redis7";
            port = 6379;
            subnet_group_name = elasticache_subnet_group.name;
          };
        in awsProvider awsEcsService awsRdsInstance elasticache_subnet_group elasticache_subnet elasticache_cluster;
      };

      # Azure configurations
      azure = {
        # Azure Container Apps
        containerApp = {
          source = "hashicorp/azurerm";
          version = "~> 3.0";
          name = "demod-agent-app";
          resource_group_name = "demod-agent-rg";
          location = "East US";
          
          container_registry = {
            name = "demodacr";
            resource_group_name = "demod-agent-rg";
          };
          
          container_app_environment = {
            name = "demod-agent";
            location = "East US";
            resource_group_name = "demod-agent-rg";
            
            revision_mode = "Single";
            
            container = {
              name = "demod-agent";
              image = "demodacr.azurecr.io/demod-agent:latest";
              cpu = 0.5;
              memory = "1.0";
              
              env = [{
                name = "FLASK_ENV";
                value = "production";
              }];
            };
          };
        };
      };

      # GCP configurations
      gcp = {
        # GKE cluster
        gkeCluster = {
          source = "hashicorp/google";
          version = "~> 5.0";
          name = "demod-agent-cluster";
          location = "us-west1";
          
          initial_node_count = 3;
          remove_default_node_pool = true;
          
          node_config = {
            machine_type = "e2-standard-2";
            oauth_scopes = [
              "https://www.googleapis.com/auth/cloud-platform"
            ];
          };
          
          node_pool = {
            name = "demod-agent-pool";
            initial_node_count = 3;
            machine_type = "e2-standard-2";
            node_locations = ["us-west1-a", "us-west1-b"];
          };
        };
      };
    };

    # ========================================
    # Development Shells
    # ========================================
    
    apps.x86_64-linux = {
      # Development environment
      devShell = devshell.mkShell {
        packages = with nixpkgs; [
          # Python development
          python311
          uv
          poetry
          black
          ruff
          mypy
          pytest
          
          # Infrastructure
          terraform
          docker
          docker-compose
          
          # Database tools
          redis
          postgresql
          
          # Monitoring
          prometheus
          grafana
          
          # Documentation
          mkdocs
          
          # Code quality
          pre-commit
          shellcheck
        ];
        
        # Development scripts
        shellHook = ''
          # Set up development environment
          echo "Setting up DeMoD Agent System development environment..."
          
          # Create logs directory
          mkdir -p logs
          
          # Copy development configuration
          cp configs/development.yaml configs/current.yaml
          
          # Install Python dependencies
          if [ ! -d ".venv" ]; then
            uv venv
          fi
          source .venv/bin/activate
          uv pip install -r requirements-dev.txt
          
          echo "Development environment ready!"
          echo "Run 'uvicorn src.api.main:app --reload' to start the development server"
        '';
      };

      # Database shell
      dbShell = devshell.mkShell {
        packages = with nixpkgs; [
          postgresql
          redis
        ];
        
        shellHook = ''
          # Database connection strings for development
          export POSTGRES_URL="postgresql://agent:password@localhost:5432/agentsystem"
          export REDIS_URL="redis://localhost:6379/0"
          
          echo "Database environment configured"
          echo "PostgreSQL: $POSTGRES_URL"
          echo "Redis: $REDIS_URL"
        '';
      };

      # Deployment shell
      deployShell = devshell.mkShell {
        packages = with nixpkgs; [
          terraform
          kubectl
          docker
          awscli2
          az-cli
          gcloud
          helm
        ];
        
        shellHook = ''
          # Set up AWS CLI
          if command -v aws >/dev/null 2>&1; then
            export AWS_DEFAULT_REGION="us-west-2"
            echo "AWS CLI configured"
          fi
          
          # Set up Azure CLI
          if command -v az >/dev/null 2>&1; then
            az account set --subscription "Demod-Production"
            echo "Azure CLI configured"
          fi
          
          # Set up GCP CLI
          if command -v gcloud >/dev/null 2>&1; then
            gcloud config set project "demod-agent-system"
            gcloud config set compute/zone "us-west1-a"
            echo "GCP CLI configured"
          fi
          
          echo "Deployment tools ready!"
        '';
      };
    };

    # ========================================
    # Build Outputs
    # ========================================
    
    # Docker build outputs
    packages.x86_64-linux = {
      dockerImage = self.packages.x86_64-linux.dockerImage;
      dockerImageCloud = self.packages.x86_64-linux.dockerImage;
    };

    # ========================================
    # NixOS Module
    # ========================================
    
    nixosModules.agent-system = { config, pkgs, lib, ... }:
      with lib; {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable DeMoD Agent System service";
          };
          
          package = lib.mkPackageOption {
            type = lib.types.package;
            default = self.packages.x86_64-linux.agent-system;
            description = "Agent System package to use";
          };
          
          environment = lib.mkOption {
            type = lib.types.str;
            default = "production";
            description = "Environment to run in (development, staging, production)";
          };
          
          apiEndpoint = lib.mkOption {
            type = lib.types.str;
            default = "http://localhost:8000";
            description = "API endpoint URL";
          };
          
          maxAgents = lib.mkOption {
            type = lib.types.int;
            default = 10;
            description = "Maximum number of agents";
          };
          
          autoSpawn = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable automatic agent spawning";
          };
          
          agentvmApiKey = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "AgentVM API key";
          };
          
          cloudProvider = lib.mkOption {
            type = lib.types.enum [ "local" "aws" "azure" "gcp" ];
            default = "local";
            description = "Cloud provider to use";
          };
          
          debug = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable debug logging";
          };
        };
        
        config = {
          # Import the agent-system package
          agentSystem = config.package;
          
          # Create systemd service
          systemd.services.agent-system = {
            description = "DeMoD Agent System API Service";
            
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            
            serviceConfig = {
              Type = "simple";
              ExecStart = "${agentSystem}/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 src.api.main:app";
              Restart = "always";
              RestartSec = 10;
              
              Environment = [
                "PYTHONPATH=${agentSystem}/src"
                "FLASK_ENV=${cfg.environment}"
              ];
              
              # User and group
              User = "agent";
              Group = "agent";
              
              # Security settings
              PrivateTmp = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              NoNewPrivileges = true;
              
              # Resource limits
              MemoryLimit = "2G";
              CPUQuota = "50%";
            };
          };
          
          # Optional nginx reverse proxy
          systemd.services.agent-system-proxy = lib.mkIf cfg.enable {
            description = "DeMoD Agent System Reverse Proxy";
            
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" "agent-system.service" ];
            
            serviceConfig = {
              Type = "simple";
              ExecStart = "${pkgs.nginx}/bin/nginx -g 'daemon off; master_process on; pid ${pkgs.runDir}/agent-system/nginx.pid;' -c ${pkgs.writeText \"nginx.conf\" cfg}";
              
              Environment = [
                "NGINX_CONF=${pkgs.writeText \"nginx.conf\" cfg}"
              ];
            };
          };
          
          # Logging configuration
          environment.etc."agent-system".source = lib.mkOrderOption {
            order = [ "agent-system" "local" ];
            destination = "file";
            target = "systemd-journald";
          };
        };
      };
    };

    # ========================================
    # Utility Scripts
    # ========================================
    
    apps.x86_64-linux = {
      # Development utilities
      scripts = {
        deploy = {
          type = "app";
          program = "${pkgs.writeShell "deploy" }/bin/deploy";
          text = ''
            #!/usr/bin/env nix-shell
            
            # Deployment script
            ${pkgs.terraform}/bin/terraform apply -auto-approve
            echo "Deployment completed"
          '';
        };
        
        # Testing scripts
        test = {
          type = "app";
          program = "${pkgs.writeShell "test" }/bin/test";
          text = ''
            #!/usr/bin/env nix-shell
            
            # Run test suite
            ${pkgs.python311}/bin/python -m pytest tests/ -v
          '';
        };
        
        # Database migration scripts
        migrate = {
          type = "app";
          program = "${pkgs.writeShell "migrate" }/bin/migrate";
          text = ''
            #!/usr/bin/env nix-shell
            
            # Database migrations
            ${pkgs.python311}/bin/python -m alembic upgrade head
            echo "Database migration completed"
          '';
        };
      };
    };
  };
}