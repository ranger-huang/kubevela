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
        patches?: [...{
            target: {
                type: string
            }
            component: #ComponentBody
        }]
    }
    // NOTE: END parameter

    // NOTE: Main Processing
    app: #ApplyEnvBindApp & {
        env:    parameter.env
        policy: parameter.policy
        app:    context.name
        // context.namespace indicates the namespace of the app
        namespace: context.namespace
        parallel: parameter.parallel
        patches: parameter.patches
    }

    // NOTE: Definitions
    #PlacementDecision: {
        namespace?: string
        cluster?:   string
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

    #ApplyEnvBindApp: {
        #do: "steps"

        env:       string
        policy:    string
        app:       string
        namespace: string
        parallel:  bool

        patches?: [...{
            target: {
                type: string
            }
            component: #ComponentBody
        }]

        env_:     env
        policy_:  policy
        patches_: patches

        prepare: #PrepareEnvBinding & {
            inputs: {
                env:    env_
                policy: policy_
                patches: patches_
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

    #PrepareEnvBinding: op.#Steps & {
        inputs: {
            env:    string
            policy: string
            patches?: [...{
                target: {
                    type: string
                }
                component: #ComponentBody
            }]
        }
        env_:     inputs.env     @step(1)
        policy_:  inputs.policy  @step(1)
        patches_: inputs.patches @step(1)

        loadEnv: #LoadEnvBindingEnv & {
            inputs: {
                env:    env_
                policy: policy_
            }
        }   @step(1)
        envConfig: loadEnv.outputs.envConfig

        placementDecisions: op.#MakePlacementDecisions & {
            inputs: {
                policyName: loadEnv.outputs.policy
                envName:    env_
                placement:  envConfig.placement
            }
        } @step(2)

        pa: op.#Steps & {
            patchedApp: {...}
            if patches_ == _|_ {
                patchedApp: op.#PatchApplication & {
                    inputs: {
                        envName: env_
                        if envConfig.selector != _|_ {
                            selector: envConfig.selector
                        }
                        if envConfig.patch != _|_ {
                            patch: envConfig.patch
                        }
                    }
                }
            }
            if patches_ != _|_ {
                patchedApp: #PatchToAllComponents & {
                    inputs: {
                        envName: env_
                        patches: patches_
                    }
                }
            }
        } @step(3)

        outputs: {
            components: pa.patchedApp.outputs.spec.components
            decisions:  placementDecisions.outputs.decisions
        }
    }
    // NOTE: END PrepareEnvBinding

    #ApplyComponentsToEnv: op.#Steps & {
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

    #PatchToAllComponents: {
      #provider: "multicluster"
      #do:       "dispatch-application-components"
      inputs: {
        envName: string
        patches: [...{
            target: {
                type: string
            }
            component: #ComponentBody
        }]
      }
      outputs: {...}
      ...
    }
    // NOTE: END PatchToAllComponents

    #LoadEnvBindingEnv: op.#Steps & {
        inputs: {
            env:    string
            policy: string
        }

        loadPolicies: op.#LoadPolicies @step(1)
        policy_:      string
        if inputs.policy == "" {
            envBindingPolicies: [ for k, v in loadPolicies.value if v.type == "env-binding" {k}]
            policy_: envBindingPolicies[0]
        }
        if inputs.policy != "" {
            policy_: inputs.policy
        }

        loadPolicy: loadPolicies.value["\(policy_)"]
        envMap: {
            for ev in loadPolicy.properties.envs {
                "\(ev.name)": ev
            }
            ...
        }
        envConfig_: envMap["\(inputs.env)"]

        outputs: {
            policy:    policy_
            envConfig: envConfig_
        }
    }
    // NOTE: END LoadEnvBindingEnv
    // NOTE: END Definitions

} // NOTE: Template End