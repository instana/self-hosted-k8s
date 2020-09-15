# The Operator

# Things to come
- High Availabilty for operator
- Operator Lifecycle Manager

# Glossary

- Tenant: A tenant is
- Tenant Unit (TU): A tenant unit is
- EUM

# Component Glossary

SHOULD ONLY CONTAIN COMPONENTS RELEVANT FOR SETTING UP THE OPERATOR

# The Operator

Currently:
- Installs all components
- Applies config changes

Will soon:
- Take care of updates
- Provide scaling facilities
- Provide scaling suggestions
- Take care of common problems

# TL;DR
THIS SHOULD CONTAIN A QUICK LIST OF STEPS TO GET THE THING RUNNING

# CRDs

The operator takes care of two CRDs, one for Instana-Cores and one for Instana-Tenant-Units.

## cores.instana.io
A core represents all components shared by an instana installation. These components wil lreceive by far the biggest amount
of load in regarts to ingress and processing.
Each core has a set of associated databases which will be used by the core itself and all Tenants with their respective
Tenant Units created as members of the core.

The operator supports multiple cores in the same Kubernetes-cluster.

## units.instana.io
Units represent individual data pools in instana. A unit could represent a department (sre/dev/qa/...),
an area (development/staging/production/...) or any other logical grouping required by the customer. Data from one unit
is not visible by any other unit.

Above the TUs is the tenant, allowing further grouping. The tenant only appears as a logical construct and allows to define
certain common properties for all its TUs (e.g. authentication, RBAC, ...).

The operator supports the creation of an arbitrary number of TUs across an arbitrary number of namespaces.

# Namespaces
In the following paragraphs you will find a recommended layout of namespaces for running [Instana](https://www.instana.com/) on Kubernetes.
The following paragraphs will be based on this image.
![Namespace Layout](images/namespace_structure.jpg)

## operator-namespace
The operator should get its own namespace where it will create/delete various configmaps during its lifetime. Theses configmaps
represent the persistent state of state machines used to interact with instana installations.
At the time of writing this document the operator doesn't expose anything outside its namespace.
All interactions happen indirectly via creating/updating/deleting the unit/core-CRs.

## core-namespace
A core namespace contains all the shared components.

The most important ones being:

- acceptor: The acceptor is the main entry point for the instana-agent and receives raw TCP-traffic.
- eum-acceptor: The End-User–Monitoring-acceptor receives HTTP traffic coming from the EUM-scripts injected into your webapps
- serverless-acceptor: The serverless-acceptor receives HTTP traffic containing metrics/traces from your serverless applications
- butler: This is the instana-IdP, handling all things security/athentication/authorization-related. It exposes the SignIn-pages via HTTP

After a core has been created the components mentioned above have to be exported outside the cluster.

butler/eum-acceptor/serverless-acceptor have an component called ingress (not a kubernetes ingress) in front of them. Expose this
component via a loadbalancer to be able to bind it to a static IP.

```yaml
TODO ADD LOADBALANCER EXAMPLE
```

The acceptor does its own TLS-termination and traffic handling. It has therefore be to be exposed with a separate loadbalancer:

```yaml
TODO ADD LOADBALANCER EXAMPLE
```



## tu-namespace
The operator supports multiple namespaces with an arbitrary number of TUs being deployed in each one.
After creating a unit-CR in the namespace the operator will kick in and deploy the components required.
There are two types of components being deployed in TU-namespace:

- The actual TU components where at least one instance per TU has to exist:
 They will be removed when their unit-CR-instance is removed
- components that are only required once for all TUs running in a certain namespace:
 They will be removed only when the namespace or the associated core is being removed.

A tu-namespace contains a service called ingress (this is NOT a kubernetes-ingress) which coordinates all requests to
the different TUs.

It is this service that has to be made available outside the cluster.
In the current iteration this should happen with a LoadBalancer to allow the binding of a static IP to a DNS-name (see
chapter on [DNS](#dns))

```yaml
TODO ADD LOADBALANCER EXAMPLE
```

# DNS
As mentioned above there are multiple endpoints to be exposed to external IP-addresses. The following description should
help to get a better understanding about how to map DNS-names to IPs.

Please also note that we will also provide [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) integration with
one of the next releaases.

## The rundown
Let's summarize what we have to export from the paragraphs above:

- acceptor from [core](#core-namespace)
- ingress from [core](#core-namespace)
- ingress from [unit](#unit-namespace)

let's asume your domain is **instana.mycompany.com**:

The **acceptor** will live under **acceptor.instana.mycompany.com** with the A record pointing to the IP of the LoadBalancer defined above.

The **core-ingress** will live under **instana.mycompany.com** with the A record pointing to the IP of the LoadBalancer defined above.
This one is responsible for enabling logging into the system and receiving serverless and eum-traffic.

The **unit-ingress** will live under **units.instana.mycompany.com** with the A record pointing to the IP of the LoadBalancer defined above.
This one is responsible for API-calls and using the instana UI.

Each tenant unit now requires a DNS entry of the form **<unit-name>-<tenant-name>.units.instana.mycompany.com**.
Each entry should have a **CNAME** pointing to **units.instana.mycompany.com**.

# troubleshoot

``` (bash)
instana-debug.sh
```
