global
  log 127.0.0.1:32000 local2
  stats socket /var/run/haproxy.sock mode 777 level admin
  {{- range .global }}
  {{ . }}
  {{- end }}

defaults
  timeout connect 5000
  timeout client  50000
  timeout server  50000
  errorfile 500 /etc/lb/500.http
  errorfile 502 /etc/lb/502.http
  errorfile 503 /etc/lb/503.http
  errorfile 504 /etc/lb/504.http
  {{- range .defaults }}
  {{ . }}
  {{- end }}

{{ if .stats }}
listen stats
  bind 0.0.0.0:{{ if .stats.port }}{{ .stats.port }}{{ else }}9090{{ end }}
  mode http
  stats uri {{ if .stats.path }}{{ .stats.path }}{{ else }}/{{ end }}
  stats admin if {{ if .stats.admin -}} TRUE {{ else -}} FALSE {{ end }}

{{ end }}

####
# START live-check
####

{{ if .health }}
frontend live_check
  bind *:{{ .health.port }}
  mode http
  monitor-uri {{ .health.path }}
{{ end }}

####
# END live-check
####

{{ range $name, $frontend := .frontends -}}
{{ if $frontend.name -}} frontend {{ $frontend.name }}
{{- else -}} frontend {{ $name }} {{ end }}

  ############################
  # START http-frontend
  ############################

  {{ if eq $frontend.mode "http" -}}
  bind *:{{ .port }} accept-proxy
  mode http

  ####
  # START frontend-options
  ####

  log 127.0.0.1:32000 local2
  option httplog
  {{- range $frontend.options }}
  {{ . }}
  {{- end }}

  ####
  # END frontend-options
  ####

  ####
  # START proxy-protocol
  ####

  acl xff_exists hdr_cnt(X-Forwarded-For) gt 0
  acl is_proxy_https dst_port 443
  http-request add-header X-Forwarded-For %[src] unless xff_exists
  http-request set-header X-Forwarded-Port %[dst_port]
  http-request add-header X-Forwarded-Proto https if is_proxy_https
  http-request add-header X-Forwarded-Proto http unless is_proxy_https

  ####
  # END proxy-protocol
  ####

  ####
  # START root-https
  # [Add HTTPS redirect for root domains if specified]
  ####

  {{ range $root := $.domains -}}
  {{ $did := $root.id -}}
  {{ if $root.scheme -}}
  acl acl_{{ $did }}_default hdr(host) -i {{ $root.host }}
  acl acl_{{ $did }}_default_https {{ if eq $root.scheme "https" -}} always_true {{ else -}} always_false {{- end }}
  redirect scheme https code 301 if !is_proxy_https acl_{{ $did }}_default acl_{{ $did }}_default_https
  {{ end }}
  {{- end }}

  ####
  # END root-https
  ####

  ####################
  # START backend-acls
  ####################

  {{ range $backend := $.backends -}}
  {{ if eq $backend.frontend $name -}}
  {{ $bid := $backend.id }}

  ############
  # START domain-acls
  ############

  {{ range $domain := $backend.domains -}}
  {{ $did := printf "%s_%s" $bid $domain.id -}}

  ####
  # START domain-https
  ####

  {{ if $domain.scheme -}}
  acl acl_{{ $did }}_https {{ if eq $domain.scheme "https" -}} always_true {{ else -}} always_false {{- end }}
  redirect scheme https code 301 if !is_proxy_https acl_{{ $did }}_https
  {{- end }}

  ####
  # END domain-https
  ####

  ####
  # START host-acls
  ####

  {{ if $domain.host -}}
  {{ if eq (index $domain.host 0) '*' -}} acl acl_{{ $did }}_domain hdr_end(host) -i {{ $domain.host }}
  {{- else if $domain.host -}} acl acl_{{ $did }}_domain hdr(host) -i {{ $domain.host }} {{- end }}
  {{- end }}

  ####
  # END host-acls
  ####

  ####
  # START path-acls
  ####

  {{ if $domain.path -}} acl acl_{{ $did }}_domain path -i {{ $domain.host }} {{- end }}

  ####
  # END path-acls
  ####

  use_backend {{ $bid }} if acl_{{ $did }}_domain
  {{- end }}

  ############
  # END domain-acls
  ############

  ####
  # START default-acls
  ####

  {{ range $root := $.domains -}}

  {{ $did := $root.id -}}

  {{ if $backend.scope }}

  {{ if eq $backend.scope "environment" }}
  acl acl_{{ $did }}_{{ $bid }}_default hdr(host) -i {{ $backend.service }}.{{ $backend.stack }}.{{ $backend.environment }}.{{ $root.host }}
  {{ else if eq $backend.scope "service" }}
  acl acl_{{ $did }}_{{ $bid }}_default hdr(host) -i {{ $backend.service }}.{{ $root.host }}
  {{ else }}
  acl acl_{{ $did }}_{{ $bid }}_default hdr(host) -i {{ $backend.service }}.{{ $backend.stack }}.{{ $root.host }}
  {{ end }}

  {{ else }}

  {{ if eq $.scope "environment" }}
  acl acl_{{ $did }}_{{ $bid }}_default hdr(host) -i {{ $backend.service }}.{{ $backend.stack }}.{{ $backend.environment }}.{{ $root.host }}
  {{ else if eq $.scope "service" }}
  acl acl_{{ $did }}_{{ $bid }}_default hdr(host) -i {{ $backend.service }}.{{ $root.host }}
  {{ else }}
  acl acl_{{ $did }}_{{ $bid }}_default hdr(host) -i {{ $backend.service }}.{{ $backend.stack }}.{{ $root.host }}
  {{ end }}

  {{ end }}

  use_backend {{ $bid }} if acl_{{ $did }}_{{ $bid }}_default

  {{ end }}

  ####
  # END default-acls
  ####

  {{- end }}
  {{- end }}

  ####################
  # END backend-acls
  ####################

  default_backend fallback

  {{- end }}

  ############################
  # END http-frontend
  ############################

  ########
  # START tcp-frontend
  ########

  {{ if eq $frontend.mode "tcp" -}}
  bind *:{{ .port }}
  mode tcp

  ####
  # START frontend-options
  ####

  log 127.0.0.1:32000 local2
  option tcplog
  {{- range $frontend.options }}
  {{ . }}
  {{- end }}

  ####
  # END frontend-options
  ####

  {{ range $backend := $.backends -}}
  {{ if eq $backend.frontend $name -}}
  default_backend {{ $backend.id }}
  {{ end }}
  {{ end }}

  {{- end }}

  ########
  # END tcp-frontend
  ########

{{ end }}

{{ range $backend := .backends -}}
backend {{ $backend.id }}
  {{ if $backend.mode -}} mode {{ $backend.mode }} {{ else }} mode http {{ end }}
  {{- $port := .port }}
  {{- range $container := .containers }}
  server {{ $container.ip }} {{ $container.ip }}:{{ $port }} {{ if not $container.healthy }} disabled {{ end }}
  {{- end }}

{{ end }}

backend fallback
  mode http
  errorfile 503 /etc/lb/404.http
