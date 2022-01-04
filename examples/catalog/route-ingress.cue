import (
	tmpl "text/template"
)

"route-ingress": {
	type: "trait"
	annotations: {}
	labels: {}
	description: "Add ingress for the compmonent."
	attributes: {
		podDisruptive: false
		appliesToWorkloads: [
			"deployment.apps",
			"statefulset.apps",
			"statefulset",
		]
	}
}

template: {
	parameter: {
		version: *"v1beta1" | "v1" | string
		annotations?: [string]: string
		labels?: [string]:      string

		domain?:    string
		subdomain?: string
		host:       *"{{.name}}.{{.subdomain}}.{{.domain}}" | string

		nameTempl: {
			text: *"{{.name}}-default" | string
			params: {...}
		}
		hostTempl?: {
			text: *host | string
			params: {...}
			if parameter.domain != _|_ && params.domain == _|_ {
				params: domain: parameter.domain
			}
			if parameter.subdomain != _|_ && params.subdomain == _|_ {
				params: subdomain: parameter.subdomain
			}
		}
	}

	parameter: {
		rules: [...{
			path:        *"/" | string
			servicePort: int | *80
			host?:       string

			if host == _|_ && parameter.hostTempl == _|_ {
				hostTempl: {
					text: *parameter.host | string
					params: {...}
					if parameter.domain != _|_ && params.domain == _|_ {
						params: domain: parameter.domain
					}
					if parameter.subdomain != _|_ && params.subdomain == _|_ {
						params: subdomain: parameter.subdomain
					}
				}
				host: tmpl.Execute(hostTempl.text, context & hostTempl.params)
			}

			if host == _|_ && parameter.hostTempl != _|_ {
				let hostTempl = parameter.hostTempl
				host: tmpl.Execute(hostTempl.text, context & hostTempl.params)
			}
		}]
	}

	_metadata: {
		// name: context.name
		name: tmpl.Execute(parameter.nameTempl.text, context & parameter.nameTempl.params)

		if parameter.annotations != _|_ {
			// +patchKey=name
			annotations: parameter.annotations
		}
		if parameter.labels != _|_ {
			// +patchKey=name
			labels: parameter.labels
		}
	}

	outputs: "ingress-\(_metadata.name)": {
		apiVersion: "networking.k8s.io/\(parameter.version)"
		kind:       "Ingress"
		metadata:   _metadata
		spec: {
			// +patchKey=host
			rules: [
				for r in parameter.rules {
					host: r.host
					http: {
						paths: [{
							path: r.path
							if parameter.version == "v1" {
								pathType: "ImplementationSpecific"
								backend: {
									service:
										name: context.name
									port:
										number: r.servicePort
								}
							}
							if parameter.version == "v1beta1" {
								backend: {
									serviceName: context.name
									servicePort: r.servicePort
								}
							}
						}]
				}
				},
			]
		}
	}
}
