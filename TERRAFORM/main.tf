# Configuration Terraform pour AWS
# Ce script crée une infrastructure de base sur AWS, incluant un VPC, des sous-réseaux, 
# un groupe de sécurité et une instance EC2.

# Définition du provider AWS
# Le provider est le plugin Terraform qui interagit avec l'API d'un service spécifique, ici AWS
provider "aws" {
  region = var.region  # La région AWS est définie par une variable
}

# Module pour créer un VPC (Virtual Private Cloud)
# Les modules sont des ensembles réutilisables de ressources Terraform
module "vpc" {
  # Source du module : il provient du registry Terraform
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"  # Utilisation de la version 3.x du module

  name = "my-vpc"  # Nom du VPC
  cidr = "10.0.0.0/16"  # Plage d'adresses IP pour le VPC

  # Définition des zones de disponibilité (AZ) et des sous-réseaux
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]  # Utilise 3 AZ dans la région spécifiée
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]  # Sous-réseaux privés
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]  # Sous-réseaux publics

  enable_nat_gateway = true  # Active une passerelle NAT pour l'accès Internet des sous-réseaux privés
  single_nat_gateway = true  # Utilise une seule passerelle NAT pour réduire les coûts

  # Tags pour identifier et organiser les ressources
  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

# Groupe de sécurité pour l'application web
# Les groupes de sécurité agissent comme un pare-feu virtuel pour les instances EC2
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id  # Associe le groupe de sécurité au VPC créé

  # Règle d'entrée : autorise le trafic HTTP entrant
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Autorise l'accès depuis n'importe quelle adresse IP
  }

  # Règle de sortie : autorise tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Tous les protocoles
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# Création d'une instance EC2 (Elastic Compute Cloud)
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2.id  # Utilise l'ID de l'AMI obtenu via la data source
  instance_type = "t3.micro"  # Type d'instance, ici une petite instance économique
  subnet_id     = module.vpc.public_subnets[0]  # Place l'instance dans le premier sous-réseau public

  # Associe le groupe de sécurité à l'instance
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "WebServer"
  }
}

# Data source pour obtenir l'AMI Amazon Linux 2 la plus récente
# Une data source permet d'utiliser des informations définies en dehors de Terraform
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]  # AMI fournie par Amazon

  # Filtre pour obtenir l'AMI spécifique d'Amazon Linux 2
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Variables
# Les variables permettent de paramétrer le code et de le rendre plus flexible
variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "environment" {
  description = "Deployment environment"
  default     = "dev"
}

# Outputs
# Les outputs permettent d'obtenir des informations sur les ressources créées
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}