provider "aws" {
  region = "us-west-2"
}

# -------------------------------
# ECS Cluster
# -------------------------------
resource "aws_ecs_cluster" "main" {
  name = "dynamic-cluster"
}

# -------------------------------
# Launch Template for Mixed CPU Spot & On-Demand Instances
# -------------------------------
resource "aws_launch_template" "cpu" {
  name_prefix   = "cpu-instance-"
  image_id      = "ami-0abcdef1234567890" # Replace with ECS-optimized AMI
  instance_type = "c5.large" # Default instance type (used in On-Demand)
  key_name      = "my-key"   # Replace with your key

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-cpu-instance"
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF
  )
}

# -------------------------------
# Auto Scaling Group (CPU) with Spot Instances
# -------------------------------
resource "aws_autoscaling_group" "cpu_asg" {
  desired_capacity     = 2
  max_size            = 5
  min_size            = 1
  vpc_zone_identifier = ["subnet-12345678"] # Replace with your subnet(s)

  mixed_instances_policy {
    launch_template {
      launch_template_id = aws_launch_template.cpu.id
      version            = "$Latest"
    }

    instances_distribution {
      on_demand_base_capacity                  = 1   # Keep at least 1 On-Demand instance
      on_demand_percentage_above_base_capacity = 30  # 30% On-Demand, 70% Spot
      spot_allocation_strategy                 = "capacity-optimized"
    }

    overrides {
      instance_type = "c5.large"
    }
    overrides {
      instance_type = "c5.xlarge"
    }
    overrides {
      instance_type = "c4.large"
    }
  }

  tag {
    key                 = "ecs.cpu"
    value               = "true"
    propagate_at_launch = true
  }
}

# -------------------------------
# Launch Template for Mixed GPU Spot & On-Demand Instances
# -------------------------------
resource "aws_launch_template" "gpu" {
  name_prefix   = "gpu-instance-"
  image_id      = "ami-0abcdef1234567890" # Replace with ECS-optimized AMI
  instance_type = "g4dn.xlarge" # Default instance type
  key_name      = "my-key"      # Replace with your key

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ecs-gpu-instance"
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF
  )
}

# -------------------------------
# Auto Scaling Group (GPU) with Spot Instances
# -------------------------------
resource "aws_autoscaling_group" "gpu_asg" {
  desired_capacity     = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = ["subnet-12345678"] # Replace with your subnet(s)

  mixed_instances_policy {
    launch_template {
      launch_template_id = aws_launch_template.gpu.id
      version            = "$Latest"
    }

    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 40  # 40% On-Demand, 60% Spot
      spot_allocation_strategy                 = "capacity-optimized"
    }

    overrides {
      instance_type = "g4dn.xlarge"
    }
    overrides {
      instance_type = "g4dn.2xlarge"
    }
    overrides {
      instance_type = "p3.2xlarge"
    }
  }

  tag {
    key                 = "ecs.gpu"
    value               = "true"
    propagate_at_launch = true
  }
}

# -------------------------------
# ECS Capacity Providers (Handles Spot vs. On-Demand)
# -------------------------------
resource "aws_ecs_capacity_provider" "cpu" {
  name = "cpu-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.cpu_asg.arn

    managed_scaling {
      status = "ENABLED"
      target_capacity = 80
    }
  }
}

resource "aws_ecs_capacity_provider" "gpu" {
  name = "gpu-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.gpu_asg.arn

    managed_scaling {
      status = "ENABLED"
      target_capacity = 80
    }
  }
}

# -------------------------------
# ECS Cluster Capacity Provider Strategy
# -------------------------------
resource "aws_ecs_cluster_capacity_providers" "gpu-cpu-capacity" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    aws_ecs_capacity_provider.cpu.name,
    aws_ecs_capacity_provider.gpu.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.cpu.name
    weight            = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.gpu.name
    weight            = 2
  }
}

# -------------------------------
# IAM Role for ECS Instances
# -------------------------------
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}
