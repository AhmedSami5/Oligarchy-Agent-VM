{
  description = "DeMoD Agent System - Distributed AI Agent Management Platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    poetry2nix.url = "github:nix-community/poetry2nix";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, flake-utils, agenix, poetry2nix, 
    pre-commit-hooks, devshell }:
    
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { 
          inherit system; 
          config.allowUnfree = true;
        };

        # Python environment with all dependencies
        pythonEnv = pkgs.python311.withPackages (ps: [
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
        ]);

        # Development environment
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Python development
            python311
            poetry
            black
            ruff
            mypy
            python3Packages.pytest
            python3Packages.pytest-asyncio
            
            # Infrastructure
            terraform
            kubectl
            docker
            docker-compose
            
            # Documentation
            mkdocs
            python3Packages.mkdocs-material
            
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
            echo "Setting up DeMoD Agent System development environment..."
            
            # Create logs directory
            mkdir -p logs
            
            # Set up Python environment
            if [ ! -d ".venv" ]; then
              python3.11 -m venv .venv
            fi
            source .venv/bin/activate
            pip install -r requirements-dev.txt
            
            echo "Development environment ready!"
            echo "Run 'uvicorn src.api.main:app --reload' to start the development server"
          '';
        };

        # Docker image
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "demod-agent-system";
          tag = "latest";
          
          config = {
            Cmd = [ "${pythonEnv}/bin/python" "-m" "uvicorn" "src.api.main:app" "--host" "0.0.0.0" "--port" "8000" ];
            WorkingDir = "/app";
            ExposedPorts = { 
              "8000/tcp" = {};
            };
            Env = [
              "PYTHONPATH=/app/src"
              "AGENT_ENV=production"
            ];
            Volumes = { 
              "/app/logs" = {};
            };
          };
          
          # Copy application code
          contents = [
            (pkgs.runCommand "app-code" {} ''
              mkdir -p $out/app/src
              cp -r ${./src} $out/app/src
              cp -r ${./configs} $out/app/configs
              cp ${./requirements.txt} $out/app/
            '')
          ];
        };

        # UI Development shell
        uiDevShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Python development
            python311
            python311Packages.pygobject3
            python311Packages.aiohttp
            python311Packages.pycairo
            
            # GTK4 and Wayland
            gtk4
            libadwaita
            cairo
            pango
            glib
            gdk-pixbuf
            wayland
            libxkbcommon
            
            # Development tools
            black
            ruff
            mypy
            python3Packages.pytest
            
            # Utilities
            jq
            curl
            git
          ];
          
          shellHook = ''
            echo "Setting up AgentVM Wayland UI development environment..."
            
            # Set up Python environment
            if [ ! -d ".venv" ]; then
              python3.11 -m venv .venv
            fi
            source .venv/bin/activate
            
            echo "UI development environment ready!"
            echo "Run 'python3 ui/wayland/agentvm_ui.py' to start the UI"
          '';
        };

        # Terraform configurations
        terraformConfigs = {
          aws = {
            # AWS provider configuration
            provider = pkgs.writeText "aws-provider.tf" ''
              terraform {
                required_providers {
                  aws = {
                    source  = "hashicorp/aws"
                    version = "~> 5.0"
                  }
                }
              }
              
              provider "aws" {
                region = "us-west-2"
              }
            '';
            
            # AWS ECS configuration
            ecs = pkgs.writeText "aws-ecs.tf" ''
              resource "aws_ecs_cluster" "demod_agent_cluster" {
                name = "demod-agent-cluster"
                
                setting {
                  name  = "containerInsights"
                  value = "enabled"
                }
                
                capacity_providers = ["FARGATE"]
                default_capacity_provider_strategies {
                  capacity_provider = "FARGATE"
                  weight            = 100
                }
              }
              
              resource "aws_ecs_service" "demod_agent_service" {
                name            = "demod-agent-service"
                cluster         = aws_ecs_cluster.demod_agent_cluster.id
                task_definition = aws_ecs_task_definition.demod_agent.arn
                desired_count   = 3
                launch_type     = "FARGATE"
                
                network_configuration {
                  subnets         = ["subnet-private", "subnet-public"]
                  security_groups = ["sg-demod-agent"]
                  assign_public_ip = true
                }
              }
            '';
            
            # Task definition
            taskDefinition = pkgs.writeText "aws-task-definition.tf" ''
              resource "aws_ecs_task_definition" "demod_agent" {
                family                   = "demod-agent"
                network_mode             = "awsvpc"
                requires_compatibilities = ["FARGATE"]
                cpu                      = "256"
                memory                   = "512"
                execution_role_arn       = "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole"
                    
                container_definitions = jsonencode([
                  {
                    name  = "demod-agent-system"
                    image = "demod-agent-system:latest"
                        
                    portMappings = [
                      {
                        containerPort = 8000
                        hostPort      = 8000
                        protocol      = "tcp"
                      }
                    ]
                        
                    environment = [
                      {
                        name  = "FLASK_ENV"
                        value = "production"
                      }
                    ]
                        
                    logConfiguration = {
                      logDriver = "awslogs"
                      options = {
                        awslogs-group         = "/ecs/demod-agent-system"
                        awslogs-region        = "us-west-2"
                        awslogs-stream-prefix = "ecs"
                      }
                    }
                  }
                ])
              }
            '';
          };
        };

        # Database shell
        dbShell = pkgs.mkShell {
          buildInputs = with pkgs; [
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
        deployShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            terraform
            kubectl
            docker
            awscli2
            azure-cli
            google-cloud-sdk
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

      in {
        # Packages
        packages = {
          default = pythonEnv;
          agent-system = pythonEnv;
          docker-image = dockerImage;
          inherit (terraformConfigs.aws) provider ecs taskDefinition;
        };

        # Development shells
        devShells = {
          default = devShell;
          ui = uiDevShell;
          db = dbShell;
          deploy = deployShell;
        };

        # Apps
        apps = {
          # Development utilities
          deploy = {
            type = "app";
            program = "${pkgs.writeShellScript "deploy" ''
              #!/usr/bin/env bash
              echo "Deploying to infrastructure..."
              terraform apply -auto-approve
              echo "Deployment completed"
            ''}";
          };
          
          test = {
            type = "app";
            program = "${pkgs.writeShellScript "test" ''
              #!/usr/bin/env bash
              echo "Running test suite..."
              python -m pytest tests/ -v
              echo "Tests completed"
            ''}";
          };
          
          migrate = {
            type = "app";
            program = "${pkgs.writeShellScript "migrate" ''
              #!/usr/bin/env bash
              echo "Running database migrations..."
              python -m alembic upgrade head
              echo "Migration completed"
            ''}";
          };
        };

        # NixOS module
        nixosModules = {
          agent-system = { config, pkgs, lib, ... }:
            with lib; {
              options.services.agent-system = {
                enable = mkEnableOption "DeMoD Agent System service";
                
                package = mkPackageOption pkgs "agent-system" {
                  default = pythonEnv;
                };
                
                environment = mkOption {
                  type = types.str;
                  default = "production";
                  description = "Environment to run in (development, staging, production)";
                };
                
                apiEndpoint = mkOption {
                  type = types.str;
                  default = "http://localhost:8000";
                  description = "API endpoint URL";
                };
                
                maxAgents = mkOption {
                  type = types.int;
                  default = 10;
                  description = "Maximum number of agents";
                };
                
                autoSpawn = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Enable automatic agent spawning";
                };
                
                agentvmApiKey = mkOption {
                  type = types.str;
                  default = "";
                  description = "AgentVM API key";
                };
                
                cloudProvider = mkOption {
                  type = types.enum [ "local" "aws" "azure" "gcp" ];
                  default = "local";
                  description = "Cloud provider to use";
                };
                
                debug = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable debug logging";
                };
              };
              
              config = mkIf config.services.agent-system.enable {
                # Create user
                users.users.agent = {
                  isSystemUser = true;
                  group = "agent";
                  description = "DeMoD Agent System user";
                };
                
                users.groups.agent = {};
                
                # Systemd service
                systemd.services.agent-system = {
                  description = "DeMoD Agent System API Service";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network-online.target" ];
                  wants = [ "network-online.target" ];
                  
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${config.services.agent-system.package}/bin/python -m uvicorn src.api.main:app --bind 0.0.0.0:8000 --workers 4";
                    Restart = "always";
                    RestartSec = 10;
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
                    
                    Environment = [
                      "PYTHONPATH=/app/src"
                      "FLASK_ENV=${config.services.agent-system.environment}"
                      "AGENTVM_API_KEY=${config.services.agent-system.agentvmApiKey}"
                      "CLOUD_PROVIDER=${config.services.agent-system.cloudProvider}"
                      "DEBUG=${if config.services.agent-system.debug then "true" else "false"}"
                    ];
                  };
                };
              };
            };
        };
      });
}