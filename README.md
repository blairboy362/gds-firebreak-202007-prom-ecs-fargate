# Prometheus on ECS Fargate

## Abstract

I wanted to see if I could run prometheus on ECS fargate in a sane way. I
discovered that the answer is "not really". I set prometheus up on ECS fargate
with an EFS volume for persistent storage. This works while there's only one
prometheus instance. This would be fine if the SLA allowed for the loss of
metrics and prometheus for 1-2 minutes every time the task or service was
updated. To make it highly available each prometheus instance needs its own
store. Then, to address the problems around duplicate metrics and skewed views
on every refresh due to the load balancer switching backing instances, I brought
thanos in; this added a lot of complexity. In this set up a 3-replica task roll
only resulted in two 30-second gaps in the metrics, which only showed up when
doing a rate over one minute (any larger and the gap disappears).

## Initial set up

* A route53 record pointing at a load balancer
* An ECS service wrapping an ECS fargate task for a prometheus instance
* An EFS volume for the prometheus time series data
* All the necessary AWS cruft to make all that work (VPC, IAM, security groups,
  EFS access points, EFS mount points, log groups etc.)

## Final set up

* A thanos sidecar added to each prometheus instance
* A thanos-query service wrapping an ECS fargate task for the thanos query
  instances
* Service discovery, which the prometheus instances register with to allow the
  thanos-query service to discover the instances
* The load balancer forwards requests to the thanos-query instances

## Hacks

* Entrypoint scripts passed in as environment variables (base64 encoded)
* Config files passed in as environment variables (base64 encoded)
* File-based "ordinal" discovery to reduce loss of metrics history

## Observations

* Managed to reduce the outage window to (effectively) a single scrape during
  task roll
* I saw one refused connection during a task roll
* When prometheus is configured to discover itself using DNS service discovery
  each instance only discovers one instance (presumably itself)

## Discussion

This is so much easier to do with kubernetes - use kubernetes instead of ECS
fargate!

I had a lot of fun with this. Disappointed the gap in metrics still appeared,
but not altogether surprised. To get it that low seems a reasonable enough
delivery for this work.

I'd like to come up with a proper solution for the "discover the ordinal" hack
I've put in with file locks. It's a shame ECS doesn't give that as an
environment variable. It's possible that over time the locks don't get tidied
properly and new instances would fail to come up. We'd need to find a way to
sort that out.

The thanos deduplication and selection of backing prometheus instance seems to
work pretty well, and wasn't that difficult to get working in the end; even if
it does end up making the overall solution a bit more complicated. The gap in
metrics would probably disappear if we added thanos' s3 backing storage as the
data from the multiple instances would be merged. But, with EFS, there's little
incentive to do this given how low the impact would be; unless EFS is really
expensive.

The entrypoint hacks that have been put in could be removed if we used docker
images derived from the upstream ones. But the config hack would need to exist
until ECS fargate allows arbitrary files to be mounted in at runtime (like k8s
`configmap` and `secret` resources).

According to the AWS docs EFS is more performant in terms of IOPS than attached
EBS volumes, so hopefully that won't be a problem.

A simpler "HA" solution would have been to have multiple ecs services and ecs
task definitions via a `count` parameter where the ordinal was templated in via
the `count.index` variable. But that would mean a concourse pipeline (or other
orchestrator) would need to manage rolling the instances and we lose a lot of
the niceness of ECS services; not very idiomatic.

## Recommendations

If HA on fargate is the desired outcome:

* EFS is fine
* Thanos is fine
* Use derived docker images so the entrypoint hack can be removed

## Further work

* Replace the file-based ordinal discovery with something else
* See how it all behaves under proper load
