"label-workload": {
	type: "trait"
	annotations: {}
	labels: {}
	description: "Add labels for component."
	attributes: {
		podDisruptive: true
		appliesToWorkloads: [
			"deployment.apps",
			"statefulset.apps",
			"job.batch",
			"statefulset",
			"microtask",
		]
	}
}
template: {
	parameter: {
		type: *"template" | "self" | "both"
		matchLabels?: [string]: string
		labels: [string]:       string
	}

	patch: {
		if parameter.type != "template" {
			metadata: labels: parameter.labels
		}
		if parameter.type != "self" {
			spec: template: metadata: labels: parameter.labels
		}
	}

	patch: {
		if parameter.type != "self" {
			if parameter.matchLabels != _|_ {
				spec: {
					selector: matchLabels: parameter.matchLabels
					template: metadata: labels: parameter.matchLabels
				}
			}
		}
	}
}
