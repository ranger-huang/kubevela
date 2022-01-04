"expose": {
	type: "trait"
	annotations: {}
	labels: {}
	description: "add service for pods"
	attributes: {
		podDisruptive: true
		appliesToWorkloads: [
			"deployment.apps",
			"statefulset.apps",
			"statefulset",
		]
	}
}
template: {
	import (
	"strings",
	)

	parameter: {
		ports: [...{
			name?:          string
			protocol:       *"TCP" | "UDP"
			containerPort?: int
			servicePort:    int
		}]
	}

	patch: {
		spec: template: spec: {
			// +patchKey=name
			containers: [{
				name: context.name
				// +patchKey=name
				ports: [
					for p in parameter.ports {
						if p.name != _|_ {
							name: p.name
						}
						if p.protocol != _|_ {
							protocol: p.protocol
						}
						if p.containerPort != _|_ {
							containerPort: p.containerPort
						}
						if p.containerPort == _|_ {
							containerPort: p.servicePort
						}
					},
				]
			}]
		}
	}

	// Service
	// outputs.service is validated by Service
	// outputs: service: corev1.#Service
	// Service definition
	outputs: service: {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      context.name
			namespace: context.namespace
			labels: {
				for k, v in context.output.metadata.labels {
					if strings.HasPrefix(k, "app.oam.dev") == false {
						"\(k)": v
					}
				}
			}
		}
		spec: {
			//type: "ClusterIP"
			selector: context.output.spec.selector.matchLabels
			// +patchKey=name
			ports: [
				for p in parameter.ports {
					name: p.name
					if p.protocol != _|_ {
						protocol: p.protocol
					}
					port: p.servicePort
					if p.containerPort != _|_ {
						targetPort: p.containerPort
					}
					if p.containerPort == _|_ {
						targetPort: p.servicePort
					}
				},
			]
		}
	}
}
