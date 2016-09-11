# rancher-lb
Active HAProxy Load Balancer as a Rancher Service

This is similar to the built-in load balancer offered by rancher, but is extended with support for the following features:

- Add arbitrary custom HAProxy configuration via service metadata
- Automatically add new services using docker labels
- Default vhost domains for services using root domains and service/stack names
- Easily expose HAProxy stats page
- Optional redirect to a custom error and/or 404 page
- Optional force redirect to https
- Redirect haproxy logs to stdout by default (this is notoriously painful to configure in docker)
- Expose a 'ping' port for maintaining host membership of external load-balancers via external health checks (think ELB)
- Support for `accept-proxy` frontend option (again, useful for ELB)

## Getting started

In its most basic form, `finboxio/rancher-lb` requires minimal configuration to work. You can try it out by deploying the docker/rancher-compose sample files included here. A brief explanation of each follows:

##### stack/docker-compose.yml

```
haproxy:
  ports:
  - 80:80/tcp
  labels:
    io.rancher.scheduler.global: 'true'
    lb.haproxy.9090.frontend: 80/http
  image: finboxio/rancher-lb

```

##### stack/rancher-compose.yml

```
haproxy:
  health_check:
    port: 80
    interval: 2000
    initializing_timeout: 20000
    unhealthy_threshold: 3
    strategy: recreate
    response_timeout: 2000
    healthy_threshold: 2
  metadata:
    stats:
      port: 9090
    global:
    - maxconn 4096
    - debug
    defaults:
    - timeout connect 5000
    domains:
    - http://rancher.dev
    scope: service
```

The docker-compose file is pretty straightforward. Run the image on all hosts and bind to port 80.

You might notice that the `global` section in our service metadata accepts arbitrary haproxy configuration lines. These will be inserted into the global configuration section of the HAProxy config file. Likewise, you can specify a `defaults` list, whose lines will be added to the `defaults` section of the HAProxy config. If you don't know what to put there, just leave them out. It'll still work. **Wow. Such power. So simple.**

The label `lb.haproxy.9090.frontend=80/http` is where the magic happens, and exactly what it does depends on how we configure our service metadata.

In this case, it tells `finboxio/rancher-lb` to create an http frontend in HAProxy that listens on port 80, and to further create a backend that balances all requests with the Host header `haproxy.rancher.dev` to port 9090 across all of the healthy containers in this service. This is our haproxy stats page, since our metadata is configured to expose that on `:9090/` (see `metadata.stats.{port,path}` in rancher-compose).

That's it. Our frontend is automatically created, our backend is automatically set up, our acls routing to that backend are automatically configured, and healthy containers are automatically added as they come and go. As services with similar labels are added/removed, the router will automatically expose/drop them.

> **IMPORTANT**
>
> Containers will only be activated if they are explicitly marked healthy by rancher. This means that if your service does not have a rancher healthcheck defined, `finboxio/rancher-lb` will **never** send traffic to any of its containers.

## Configuration

#### tl;dr

To customize your `finboxio/rancher-lb` deployment, you can define options in the service metadata. Any of these options can be omitted, but here's a complete sample of what's supported. Details of what each option does are given in the following sections:

```
  metadata:
    scope: {service|stack|environment}
    health:
      port: <port>
      path: <path>
    stats:
      port: <port>
      path: <path>
      admin: {true|false}
    global:
      - <global setting 1>
      - <global setting 2>
      - ...
    defaults:
      - <default setting 1>
      - <default setting 2>
      - ...
    domains:
      - <root domain 1>
      - ...
    frontends:
      <port>/{http|tcp}:
        proxy: {true|false}
        options:
          - <frontend option 1>
          - <frontend option 2>
          - ...
      <other-port>/{http|tcp}:
        ...
      ...
```

You can also specify custom error/fallback pages with environment variables `ERROR_URL=<url>` and `FALLBACK_URL=<url>`.

Finally, to enable automatic service registration with your load-balancer, add the following labels to each **health-checked** service you'd like to access. Note that `*.frontend` is required, while `*.domain[s]` is optional.

`<lb-stack>.<lb-service>.<service-port>.frontend=<frontend-port>/{http|tcp}`

`<lb-stack>.<lb-service>.<service-port>.domain[s]={http|https}://<hostname1>,...`

#### The details

It may not be obvious from our sample configuration, but the labels that `finboxio/rancher-lb` recognizes and uses to update the HAProxy config take the following form:

```
<lb-stack>.<lb-service>.<container-port>.{frontend|domain|domains}=<value>
```

`lb-stack` and `lb-service` are the stack and service name of your `finboxio/rancher-lb` deployment. In the sample case, it's assumed that `finboxio/rancher-lb` is deployed as a service named `haproxy` in a stack named `lb`. Using dynamic labels like this allows us to run multiple load balancer deployments and only expose certain services/ports on one or the other without conflicts. `container-port` tells our load-balancer to apply the corresponding rule to the given container port. This allows us to expose different ports of the same service under different hostnames or frontend ports.

##### Specifying a frontend

In the sample configuration, we specified the frontend value for our stats page as `80/http`. In general, any value of the form `<port>/{http|tcp}` will configure an http or tcp haproxy frontend listening on port `<port>` in the `rancher-lb` container and add ACL rules for your service to this frontend. **It's your responsibility to make sure this port is appropriately exposed to whoever needs to access it.**

If you want to set defaults or otherwise further configure this frontend, you can add details to your `rancher-lb` service metadata under the `frontends` key, eg:

```
metadata:
  frontends:
    80/http:
      proxy: true
      options:
        - acl not_found status 404
        - acl type_html res.hdr(Content-Type) -m sub text/html
        - http-request capture req.hdr(Host) len 64
        - http-response redirect location https://null.finbox.io/?href=http://%{+Q}[capture.req.hdr(0)]%HP code 303 if not_found type_html

```

The `proxy` setting enables proxy-protocol for the frontend. If you don't know what that is, you probably don't want it, but it is really useful when running behind something like ELB, as it's required if you want to support websockets (I think), redirect to https, or get the original client IP passed along.

> **Protip**
>
> This specific configuration in `options` is an example of a useful haproxy trick to set up a universal 404 page for all of your services. It listens for 404 html responses for any of your backends and redirects them all to a single page with a reference to the missing resource that was requested.

You should be aware that **it's impossible to have both a tcp and an http frontend listening on the same port.** So try not to specify conflicting labels like `lb.haproxy.5000.frontend=80/tcp` on one service and `lb.haproxy.8080=80/http` on another. It doesn't make sense and it won't work. I don't know exactly what will happen, but all of your friends will definitely make fun of you.

##### Specifying domains

Just like we specified our frontend, we can also specify one or more domains that should be routed to our service.

```
lb.haproxy.9090.domains=http://foo.finbox.io,https://bar.finbox.io
```

> If you only need one domain and have a ***perfectly rational*** aversion to unnecessary pluralization like me, you can use the form
`lb.haproxy.9090.domain=http://foo.finbox.io`

**It's your responsibility to ensure that the DNS records for these domains are properly configured to point to your load-balancer.**

This will setup ACLs such that incoming requests with a `Host` header matching `foo.finbox.io` or `bar.finbox.io` will be routed to port 9090 of your service.

Additionally, any `bar.finbox.io` request that is not sent over ssl will be redirected to `https://bar.finbox.io`.

> **Note**
>
> This https redirection assumes you're using proxy-protocol, and that the destination port for all https traffic is 443. If either of these assumptions aren't true, it probably won't behave the way you want it to. This project doesn't have built-in support for local SSL termination (though you could probably set it up with metadata and mounted certs). It's limited in this respect simply because it fits the only use-case we have right now (running everything behind ELB with SSL termination there using ACM certificates), but PRs are welcome.

##### Default domains

You might have noticed that we didn't specify any domains for our stats page in the sample configuration. `finboxio/rancher-lb` will generate a default domain for any service with a registered frontend using `<scope>.<domain>` semantics.

`<scope>` can be defined in your service metadata, and it determines the prefix for default domains:

Scope | Prefix
--- | ---
service |  `<service_name>`
stack (default) | `<service_name>.<stack_name>`
environment | `<service_name>.<stack_name>.<environment_name>`

This prefix is combined with each root `domain` specified in your service metadata (you may specify more than one), to generate a list of default domains for each service.

So in the sample configuration, we're using the `service` scope, and have specified a single root domain of `http://rancher.dev`. Since our stats page is running under a service named `haproxy`, default rules are created to route `Host: haproxy.rancher.dev` traffic to it. If we're happy with that, we don't need to specify any additional domains.

Note that the https redirection semantics described above also apply to root domains if you specify them with `https://` protocol.

> It goes without saying (but should probably be said anyways) that vhosts don't apply to tcp-only frontends. Any domains you specify for a service with a tcp frontend will be ignored.

##### Custom error page

Custom error pages can be configured via environment variables. If you run this load-balancer with `ERROR_URL=<your-url.com>`, errors generated by HAProxy will trigger a redirection to `your-url.com`. This works for things like 504 gateway timeouts, 503 no healthy servers available, etc. but does not redirect for errors generated from your own web service.

You can also specify a `FALLBACK_URL=<not-found.com>` url. If a request comes for which no appropriate backend can be found, it will be redirected to this url. The subtle difference between this and `ERROR_URL` allows you to send visitors to different pages depending on whether a service is unhealthy or simply does not exist.

When such a redirect is activated, HAProxy will append an `?href=` query parameter with the value of the original url that was requested, so you can react accordingly on your custom error/fallback page.

> These urls should obviously be accessible independent of this load-balancer. We host ours statically on S3.

##### Liveness check

Since we run everything behind ELB, it's important to be able to automatically determine when an instance is ready to accept traffic. In your service metadata, you can configure a 'ping' port that always reports 200.

```
metadata:
	health:
		port: 79
		path: /
```

> The `path` property is optional here. Also, make sure you bind this port to the host if you plan to use it for something like ELB healthchecks.

### Possible improvements

`finboxio/rancher-lb` is super flexible and is works really well for what we need right now, so we don't have plans to add anything in the near-term. But here's a list of things that I could see us needing in the future or might be cool to add if anyone wants to submit a PR.

- [ ] LetsEncrypt support
- [ ] Local SSL termination
- [ ] Routing based on uri paths as well as hostnames (partially implemented, totally untested)
- [ ] Use [janeczku/rancher-template](https://github.com/janeczku/rancher-template) to simplify the config templates
