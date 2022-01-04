microservice: {
	type:        "workload"
	description: "Describes a microservice combo Deployment with Service"
	labels: {}
	annotations: {}
	attributes: definitionRef: {
		version: "v1"
		name:    "deployment.apps"
	}
}

template: {
	parameter: {
		// +usage=Which image would you like to use for your service
		// +short=i
		image: string | {
			registry:   *"docker.io" | string
			repository: string
			tag?:       string
		}

		// +usage=Commands to run in the container
		cmd?: [...string]

		cpu?:    string
		memory?: string
		//strategy?: apps.#DeploymentStrategy

		// +usage=Optional duration in seconds the pod needs to terminate gracefully
		podShutdownGraceSeconds: *30 | int

		// If addRevisionLabel is true, the appRevision label will be added to the underlying pods
		addRevisionLabel: *false | bool

		// +usage=Declare volumes and volumeMounts
		volumes?: [...{
			name:      string
			mountPath: string
			// +usage=Specify volume type, options: "pvc","configMap","secret","emptyDir"
			type: "pvc" | "configMap" | "secret" | "emptyDir"
			if type == "pvc" {
				claimName: string
				subPath?:  string
			}
			if type == "configMap" {
				defaultMode: *420 | int
				cmName:      string
				subPath?:    string
				items?: [...{
					key:  string
					path: string
					mode: *511 | int
				}]
			}
			if type == "secret" {
				defaultMode: *420 | int
				secretName:  string
				subPath?:    string
				items?: [...{
					key:  string
					path: string
					mode: *511 | int
				}]
			}
			if type == "emptyDir" {
				medium: *"" | "Memory"
			}
		}]
	}

	_matchLabels: {
		"app":                   context.name
		"app.oam.dev/component": context.name
		if parameter.addRevisionLabel {
			"app.oam.dev/appRevision": "v\(context.appRevisionNum)"
			"version":                 "v\(context.appRevisionNum)"
		}
	}

	// Deployment
	// output is validated by Deployment.
	// output: apps.#Deployment
	output: {
		apiVersion: "apps/v1"
		kind:       "Deployment"
		metadata: {
			name:      context.name
			namespace: context.namespace
			labels:    _matchLabels
		}
		spec: {
			selector: matchLabels: _matchLabels
			template: {
				metadata: {
					labels: _matchLabels
				}
				spec: {
					terminationGracePeriodSeconds: parameter.podShutdownGraceSeconds
					containers: [{
						name: context.name
						if parameter.image.tag != _|_ {
							image: parameter.image.registry + "/" + parameter.image.repository + ":" + parameter.image.tag
						}
						if parameter.image.tag == _|_ {
							image: parameter.image
						}
						if parameter["cmd"] != _|_ {
							command: parameter.cmd
						}
					}]
				}
			}
		}
	}

	// Deployment
	// output parameter cpu and memory
	// output: apps.#Deployment
	output: {
		// patchKey=name
		spec: template: spec: containers: [{
			name: context.name

			resources: {
				requests: {
					if parameter.cpu != _|_ {
						cpu: parameter.cpu
					}
					if parameter.memory != _|_ {
						memory: parameter.memory
					}
				}
			}

		}]
	}

	// Deployment
	// output parameter volumes
	// output: apps.#Deployment
	output: {
		if parameter.volumes != _|_ {
			spec: template: spec: {
				// patchKey=name
				containers: [{
					name: context.name
					volumeMounts: [ for v in parameter.volumes {
						{
							mountPath: v.mountPath
							name:      v.name
							if v.subPath != _|_ {
								subPath: v.subPath
							}
						}}]
				}]

				volumes: [ for v in parameter.volumes {
					{
						name: v.name
						if v.type == "pvc" {
							persistentVolumeClaim: {
								claimName: v.claimName
							}
						}
						if v.type == "configMap" {
							configMap: {
								defaultMode: v.defaultMode
								name:        v.cmName
								if v.items != _|_ {
									items: v.items
								}
							}
						}
						if v.type == "secret" {
							secret: {
								defaultMode: v.defaultMode
								secretName:  v.secretName
								if v.items != _|_ {
									items: v.items
								}
							}
						}
						if v.type == "emptyDir" {
							emptyDir: {
								medium: v.medium
							}
						}
					}}]
			}
		}
	}
}
