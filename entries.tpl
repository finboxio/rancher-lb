{{- $split := getenv "SPLIT_TOKEN" "__split__" }}
{{- range $s, $stack_name := ls "/stacks" }}
{{- range $i, $service_name := ls (printf "/stacks/%s/services" $stack_name) }}
{{- range $l, $label := ls (printf "/stacks/%s/services/%s/labels" $stack_name $service_name) }}
{{- $list := split $label "." }}
{{- if eq (index $list 0) "lb" }}
{{- $port := index $list 1 }}
{{- $key := index $list 2 }}
{{- $value := getv (printf "/stacks/%s/services/%s/labels/%s" $stack_name $service_name $label) }}
{{ $stack_name }}{{ $split }}{{ $service_name }}{{ $split }}{{ $port }}{{ $split }}{{ $key }}{{ $split }}{{ $value }}
{{- range $c, $container_name := ls (printf "/stacks/%s/services/%s/containers" $stack_name $service_name) }}
{{- if exists (printf "/stacks/%s/services/%s/containers/%s/primary_ip" $stack_name $service_name $container_name) }}
{{- $ip := getv (printf "/stacks/%s/services/%s/containers/%s/primary_ip" $stack_name $service_name $container_name) }}
{{- $health := getv (printf "/stacks/%s/services/%s/containers/%s/health_state" $stack_name $service_name $container_name) }}
{{ $stack_name }}{{ $split }}{{ $service_name }}{{ $split }}{{ $port }}{{ $split }}container{{ $split }}{{ $ip }}{{ $split }}{{ $health }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
