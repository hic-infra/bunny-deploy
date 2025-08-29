locals {
  image     = var.image
  namespace = "bunny"

  bunny_conf = yamldecode(file("${path.module}/${var.bunnies_yaml}"))

  deployments = flatten([for bunny in local.bunny_conf.bunnies : [
    for connection in bunny.connections : {
      name          = format("%s.%s-%s", bunny.name, connection.endpoint, split("-", connection.collection_id)[3])
      data          = bunny.data
      collection_id = connection.collection_id
      endpoint      = connection.endpoint
      debug         = lookup(connection, "debug", "INFO")
    }
    ]
  ])
}

data "kubernetes_secret_v1" "endpoint" {
  for_each = { for endpoint in local.bunny_conf.endpoints : endpoint.name => endpoint.secret }
  metadata {
    namespace = local.namespace
    name      = each.value
  }
}

resource "kubernetes_secret_v1" "rds" {
  metadata {
    namespace = local.namespace
    name      = "rds"
  }

  data = {
    username = aws_rds_cluster.bunny.master_username
    password = aws_rds_cluster.bunny.master_password
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "data_env" {
  metadata {
    namespace = local.namespace
    name      = "data-env"
  }

  data = {
    DATASOURCE_DB_USERNAME   = aws_rds_cluster.bunny.master_username
    DATASOURCE_DB_PASSWORD   = aws_rds_cluster.bunny.master_password
    DATASOURCE_DB_DRIVERNAME = "postgresql"
    DATASOURCE_DB_SCHEMA     = "public"
    DATASOURCE_DB_PORT       = aws_rds_cluster.bunny.port
    DATASOURCE_DB_HOST       = aws_rds_cluster.bunny.endpoint
  }
}

resource "kubernetes_deployment_v1" "bunny" {
  for_each = { for deployment in local.deployments : "${deployment.collection_id}" => deployment }

  metadata {
    namespace = local.namespace
    name      = each.value.name
    labels = {
      app = "bunny"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "bunny"
      }
    }

    replicas = 1

    template {
      metadata {
        labels = {
          app = "bunny"
        }
      }

      spec {
        container {
          name  = "availabunny"
          image = local.image

          env {
            name  = "TASK_API_TYPE"
            value = "a"
          }

          env {
            name  = "COLLECTION_ID"
            value = each.value.collection_id
          }

          env {
            name  = "LOW_NUMBER_SUPPRESSION_THRESHOLD"
            value = each.value.data.suppression
          }

          env {
            name  = "DATASOURCE_DB_DATABASE"
            value = each.value.data.source_db
          }

          env {
            name  = "ROUNDING_TARGET"
            value = each.value.data.rounding
          }

          env {
            name  = "POLLING_INTERVAL"
            value = 5
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.data_env.metadata[0].name
            }
          }

          env {
            name = "TASK_API_BASE_URL"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.endpoint[each.value.endpoint].metadata[0].name
                key  = "address"
              }
            }
          }

          env {
            name = "TASK_API_USERNAME"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.endpoint[each.value.endpoint].metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "TASK_API_PASSWORD"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.endpoint[each.value.endpoint].metadata[0].name
                key  = "password"
              }
            }
	  }

	  env {
	    name  = "BUNNY_LOGGER_LEVEL"
	    value = each.value.debug
	  }
        }

        container {
          name  = "distribunny"
          image = local.image

          env {
            name  = "TASK_API_TYPE"
            value = "b"
          }

          env {
            name  = "COLLECTION_ID"
            value = each.value.collection_id
          }

          env {
            name  = "LOW_NUMBER_SUPPRESSION_THRESHOLD"
            value = each.value.data.suppression
          }

          env {
            name  = "DATASOURCE_DB_DATABASE"
            value = each.value.data.source_db
          }

          env {
            name  = "ROUNDING_TARGET"
            value = each.value.data.rounding
          }

          env {
            name  = "POLLING_INTERVAL"
            value = 5
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.data_env.metadata[0].name
            }
          }

          env {
            name = "TASK_API_BASE_URL"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.endpoint[each.value.endpoint].metadata[0].name
                key  = "address"
              }
            }
          }

          env {
            name = "TASK_API_USERNAME"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.endpoint[each.value.endpoint].metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "TASK_API_PASSWORD"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret_v1.endpoint[each.value.endpoint].metadata[0].name
                key  = "password"
              }
            }
	  }

	  env {
	    name  = "BUNNY_LOGGER_LEVEL"
	    value = each.value.debug
	  }
        }
      }
    }

  }
}
