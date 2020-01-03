
0.3.0 / 2020-01-02
==================

  * add gitignore
  * Add support for basic auth in domain

0.2.1 / 2017-09-17
==================

  * Update stack file

0.2.0 / 2017-09-17
==================

  * Update makefile
  * Update stack file
  * Init npm package
  * Upgrade stack files
  * Add release scripts

0.1.2 / 2016-11-09
==================

  * update makefile
  * reload haproxy with only one pid

0.1.1 / 2016-10-28
==================

  * add X-Path-Prefix header when path is rewritten (for safe redirects)

0.1.0 / 2016-10-28
==================

  * move default backend selection below custom domains
  * add support for path-based routing

0.0.10 / 2016-10-12
===================

  * make default log level 'info'
  * make default log level 'warn'
  * add rancher deploy command to makefile
  * remove .dev tld
  * readme updates
  * readme updates
  * document the sonofabitch

0.0.9 / 2016-09-10
==================

  * setup default errorfiles if not given

0.0.8 / 2016-09-10
==================

  * add checks for ERROR_URL and FALLBACK_URL before replacing errorfiles
  * update example domain to rancher.dev

0.0.7 / 2016-09-10
==================

  * make proxy-protocol optional

0.0.6 / 2016-09-10
==================

  * use absolute path for entrypoint

0.0.5 / 2016-09-10
==================

  * add sample stack for local rancher cluster
  * set entrypoint in dockerfile

0.0.4 / 2016-09-06
==================

  * fix https-redirect rules
  * only redirect to https for root domain if host matches

0.0.3 / 2016-08-25
==================

  * add latest/dev tags to current docker build

0.0.2 / 2016-08-25
==================

  * check container state and health before exposing
  * recognize labels based on <stack>.<service>.<port>.<key> pattern

0.0.1 / 2016-08-25
==================

  * Initial commit
