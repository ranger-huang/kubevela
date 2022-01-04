import (
	"vela/op"
)

"deploy2env": {
	type: "workflow-step"
	annotations: {}
	labels: {}
	description: "Deploy env binding component to target env"
}

template: { // NOTE: Template Start
    // NOTE: parameter
    parameter: {
        // +usage=Declare the name of the env-binding policy, if empty, the first env-binding policy will be used
        policy: string
        // +usage=Declare the name of the env in policy
        env: string
        parallel: *false | bool
		selector?: components: [...string]
        patches: [...#PatchTarget]
        _patched: len(patches) > 0
    }
    // NOTE: END parameter

    // NOTE: Definitions
    #PlacementDecision: {
        namespace?: string
        cluster?:   string
    }

    #PatchTarget: {
       target: {
           type: string
           selector: [...string]
       }
       component: #ComponentBody
    }
    #Component: {
        name: string
        type: string
        #ComponentBody
    }
    #ComponentBody: {
        properties?: {...}
        traits?: [...{
            type:     string
            disable?: bool
            properties: {...}
        }]
        ...
    }

    #PrepareEnvBinding: {
        #provider: "multicluster"
        #do:       "prepare-env-binding"
        #type: "PrepareEnvBinding"

        inputs: {
            envName: string
            policy:  string
            selector?: components: [...string]
            patches: [...#PatchTarget]
        }

        outputs: {
            // components: [...#Component]
            // decisions: [...#PlacementDecision]
            ...
        }
        ...
    }
    // NOTE: END PrepareEnvBinding

    #ApplyComponentsToEnv: op.#Steps & {
        #type: "ApplyComponentsToEnv"
        inputs: {
            decisions: [...#PlacementDecision]
            components: [...#Component]
            env:         string
            waitHealthy: bool
        } @step(1)

        outputs: op.#Steps & {
            for decision in inputs.decisions {
                for key, comp in inputs.components {
                    "\(decision.cluster)-\(decision.namespace)-\(key)": op.#ApplyComponent & {
                        value: comp
                        if decision.cluster != _|_ {
                            cluster: decision.cluster
                        }
                        if decision.namespace != _|_ {
                            namespace: decision.namespace
                        }
                        waitHealthy: inputs.waitHealthy
                        env:         inputs.env
                    } @step(1)
                }
            }
        } @step(2)
    }
    // NOTE: END ApplyComponentsToEnv

    // NOTE: Main
    #ApplyEnvBindApp: {
        #do: "steps"
        #type: "ApplyEnvBindApp"
        env:       string
        policy:    string
        app:       string
        namespace: string
        parallel:  bool
		selector?: components: [...string]
        patches: [...#PatchTarget]

        env_:     env
        policy_:  policy
        patches_: patches
        selector_: selector

        prepare: #PrepareEnvBinding & {
            #exec: "prepare-env-binding"
            inputs: {
                envName:  env_
                policy:   policy_
                patches:  patches_
                if selector_ != _|_ {
                    selector: selector_
                }
            }
        } @step(1)

        apply: #ApplyComponentsToEnv & {
            inputs: {
                decisions:   prepare.outputs.decisions
                components:  prepare.outputs.components
                env:         env_
                waitHealthy: !parallel
            }
        } @step(2)

        if parallel {
            wait: #ApplyComponentsToEnv & {
                inputs: {
                    decisions:   prepare.outputs.decisions
                    components:  prepare.outputs.components
                    env:         env_
                    waitHealthy: true
                }
            } @step(3)
        }
    }
    // NOTE: END ApplyEnvBindApp
    // NOTE: END Definitions

    // NOTE: Main Processing
    app: #ApplyEnvBindApp & {
        #exec: "apply-env-bind-app"
        env:    parameter.env
        policy: parameter.policy
        app:    context.name
        // context.namespace indicates the namespace of the app
        namespace: context.namespace
        parallel:  parameter.parallel
        patches:   parameter.patches
        if parameter.selector != _|_ {
          selector:  parameter.selector
        }
    }

} // NOTE: Template End
