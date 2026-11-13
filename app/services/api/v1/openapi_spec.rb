# frozen_string_literal: true

module Api
  module V1
    class OpenapiSpec
      def self.generate
        {
          openapi: "3.1.0",
          info: {
            title: "Syncretica Platform REST API",
            version: "1.0.0",
            description: "Full programmatic REST API for the Syncretica comparative mythology and archetype research platform."
          },
          servers: [
            { url: "/api/v1", description: "Default v1 endpoint" }
          ],
          paths: {
            "/status" => {
              get: {
                summary: "Platform status, health, and entity statistics",
                operationId: "getPlatformStatus",
                responses: {
                  "200" => { description: "Current platform status and counts" }
                }
              }
            },
            "/openapi.json" => {
              get: {
                summary: "OpenAPI 3.1 specification for Syncretica",
                operationId: "getOpenapiSpec",
                responses: {
                  "200" => { description: "OpenAPI schema document" }
                }
              }
            },
            "/search" => {
              get: {
                summary: "Cross-resource semantic or keyword search across Gods and Myths",
                operationId: "searchAll",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[all god myth], default: "all" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: {
                  "200" => { description: "Search results with similarity distances" }
                }
              }
            },
            "/pantheons" => {
              get: {
                summary: "List pantheons",
                operationId: "listPantheons",
                parameters: [
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "include_gods", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of pantheons" } }
              },
              post: {
                summary: "Create a pantheon",
                operationId: "createPantheon",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[name description],
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created pantheon" } }
              }
            },
            "/pantheons/{id}" => {
              get: {
                summary: "Get pantheon details",
                operationId: "getPantheon",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_gods", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Pantheon details" } }
              },
              patch: {
                summary: "Update pantheon",
                operationId: "updatePantheon",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated pantheon" } }
              },
              delete: {
                summary: "Delete pantheon",
                operationId: "deletePantheon",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Pantheon deleted" } }
              }
            },
            "/pantheons/upsert_batch" => {
              post: {
                summary: "Batch upsert pantheons",
                operationId: "batchUpsertPantheons",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[pantheons],
                        properties: {
                          pantheons: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted pantheons" } }
              }
            },
            "/pantheons/populate" => {
              post: {
                summary: "Trigger LLM discovery of pantheons",
                operationId: "populatePantheons",
                parameters: [
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/pantheons/{id}/populate_gods" => {
              post: {
                summary: "Trigger LLM discovery of gods for a single pantheon",
                operationId: "populatePantheonGods",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/gods" => {
              get: {
                summary: "List/filter gods",
                operationId: "listGods",
                parameters: [
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "pantheon", in: "query", required: false, schema: { type: "string" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_myth", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of gods" } }
              },
              post: {
                summary: "Create a god",
                operationId: "createGod",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[pantheon_id name description],
                        properties: {
                          pantheon_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created god" } }
              }
            },
            "/gods/search" => {
              get: {
                summary: "Semantic or keyword search for gods",
                operationId: "searchGods",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "God search results" } }
              }
            },
            "/gods/{id}" => {
              get: {
                summary: "Get god details",
                operationId: "getGod",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_myth", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "God details" } }
              },
              patch: {
                summary: "Update god",
                operationId: "updateGod",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } },
                          pantheon_id: { type: "integer" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated god" } }
              },
              delete: {
                summary: "Delete god",
                operationId: "deleteGod",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "God deleted" } }
              }
            },
            "/gods/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor gods by cosine distance",
                operationId: "getGodNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/gods/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for god",
                operationId: "generateGodEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/gods/{id}/populate_myth" => {
              post: {
                summary: "Discover/populate myth for a god via LLM",
                operationId: "populateGodMyth",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Myth created" }, "202" => { description: "Job queued" } }
              }
            },
            "/gods/populate" => {
              post: {
                summary: "Trigger bulk LLM god discovery",
                operationId: "populateAllGods",
                parameters: [
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/gods/upsert_batch" => {
              post: {
                summary: "Batch upsert gods for a pantheon",
                operationId: "batchUpsertGods",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[pantheon_id gods],
                        properties: {
                          pantheon_id: { type: "integer" },
                          gods: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted gods" } }
              }
            },
            "/myths" => {
              get: {
                summary: "List/filter myths",
                operationId: "listMyths",
                parameters: [
                  { name: "god_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of myths" } }
              },
              post: {
                summary: "Create/upsert a myth for a god",
                operationId: "createMyth",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[god_id themes],
                        properties: {
                          god_id: { type: "integer" },
                          themes: { type: "object", additionalProperties: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created myth" } }
              }
            },
            "/myths/search" => {
              get: {
                summary: "Semantic or keyword search for myths",
                operationId: "searchMyths",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Myth search results" } }
              }
            },
            "/myths/{id}" => {
              get: {
                summary: "Get myth details",
                operationId: "getMyth",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Myth details" } }
              },
              patch: {
                summary: "Update myth themes",
                operationId: "updateMyth",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[themes],
                        properties: {
                          themes: { type: "object", additionalProperties: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated myth" } }
              },
              delete: {
                summary: "Delete myth",
                operationId: "deleteMyth",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Myth deleted" } }
              }
            },
            "/myths/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor myths by cosine distance",
                operationId: "getMythNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "pantheon_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/myths/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for myth",
                operationId: "generateMythEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/myths/populate" => {
              post: {
                summary: "Trigger bulk LLM myth discovery",
                operationId: "populateAllMyths",
                parameters: [
                  { name: "god_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/clusters" => {
              get: {
                summary: "Compute or fetch live clusters",
                operationId: "getLiveClusters",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[God Myth], default: "God" } },
                  { name: "level", in: "query", required: false, schema: { type: "integer", minimum: 1, maximum: 15, default: 5 } },
                  { name: "full_coverage", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "force", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Clustering result" } }
              }
            },
            "/clusters/snapshot" => {
              post: {
                summary: "Compute and save a cluster snapshot",
                operationId: "createSnapshotFromCluster",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[God Myth], default: "God" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Persisted ClusterSnapshot" } }
              }
            },
            "/cluster_snapshots" => {
              get: {
                summary: "List cluster snapshots",
                operationId: "listClusterSnapshots",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[God Myth] } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of snapshots" } }
              },
              post: {
                summary: "Create and persist a snapshot",
                operationId: "createClusterSnapshot",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[God Myth], default: "God" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created snapshot" } }
              }
            },
            "/cluster_snapshots/{id}" => {
              get: {
                summary: "Get cluster snapshot details with groups",
                operationId: "getClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_groups", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_reports", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Snapshot details" } }
              },
              delete: {
                summary: "Delete cluster snapshot",
                operationId: "deleteClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Snapshot deleted" } }
              }
            },
            "/cluster_snapshots/{cluster_snapshot_id}/cluster_groups" => {
              get: {
                summary: "List cluster groups in a snapshot",
                operationId: "listSnapshotGroups",
                parameters: [
                  { name: "cluster_snapshot_id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "List of cluster groups" } }
              }
            },
            "/cluster_groups/{id}" => {
              get: {
                summary: "Get cluster group details with members",
                operationId: "getClusterGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cluster group details" } }
              }
            },
            "/cluster_reports" => {
              get: {
                summary: "List cluster reports",
                operationId: "listClusterReports",
                parameters: [
                  { name: "cluster_snapshot_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[God Myth] } },
                  { name: "status", in: "query", required: false, schema: { type: "string" } },
                  { name: "is_detailed", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of cluster reports" } }
              },
              post: {
                summary: "Create a cluster synthesis report",
                operationId: "createClusterReport",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[cluster_snapshot_id],
                        properties: {
                          cluster_snapshot_id: { type: "integer" },
                          prompt: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created report" } }
              }
            },
            "/cluster_reports/{id}" => {
              get: {
                summary: "Get cluster report details",
                operationId: "getClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_summaries", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_sub_reports", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Cluster report details" } }
              },
              delete: {
                summary: "Delete cluster report",
                operationId: "deleteClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Report deleted" } }
              }
            },
            "/cluster_reports/{id}/deep_synthesis" => {
              post: {
                summary: "Create detailed 3-phase report from an existing report",
                operationId: "createDeepSynthesisReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          batch_size: { type: "integer", minimum: 2, maximum: 50, default: 5 }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created deep synthesis report" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/summaries" => {
              get: {
                summary: "List Phase 1 per-cluster summaries",
                operationId: "listReportSummaries",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of summaries" } }
              }
            },
            "/cluster_report_summaries/{id}" => {
              get: {
                summary: "Get a single cluster report summary",
                operationId: "getReportSummary",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Summary details" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/sub_reports" => {
              get: {
                summary: "List Phase 2 batch sub-reports",
                operationId: "listReportSubReports",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of sub-reports" } }
              }
            },
            "/cluster_sub_reports/{id}" => {
              get: {
                summary: "Get a single batch sub-report",
                operationId: "getReportSubReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Sub-report details" } }
              }
            },
            "/jobs" => {
              get: {
                summary: "List recent background jobs",
                operationId: "listJobs",
                parameters: [
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Recent jobs" } }
              }
            },
            "/jobs/{id}" => {
              get: {
                summary: "Get status and progress of a background job",
                operationId: "getJobStatus",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "string" } }
                ],
                responses: { "200" => { description: "Job status" } }
              }
            },
            "/settings" => {
              get: {
                summary: "Get platform embedding and LLM settings",
                operationId: "getSettings",
                responses: { "200" => { description: "Settings and statistics" } }
              }
            },
            "/settings/context_window" => {
              patch: {
                summary: "Update LLM context window",
                operationId: "updateContextWindow",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[context_window],
                        properties: {
                          context_window: { type: "integer", minimum: 4096 }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated context window" } }
              }
            },
            "/settings/generate_embeddings" => {
              post: {
                summary: "Enqueue bulk embedding generation",
                operationId: "generateAllEmbeddings",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[model_type],
                        properties: {
                          model_type: { type: "string", enum: %w[God Myth] },
                          only_missing: { type: "boolean", default: true }
                        }
                      }
                    }
                  }
                },
                responses: { "202" => { description: "Job enqueued" } }
              }
            }
          }
        }
      end
    end
  end
end
