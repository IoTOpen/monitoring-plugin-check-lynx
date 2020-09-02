# monitoring-plugin-check-lynx
This is a simple plugin for monitoring your Lynx devices in [Op5
Monitor](https://www.itrsgroup.com/products/op5-monitor),
[Icinga](https://www.icinga.org/), [Naemon](http://naemon.github.io/),
[Nagios](http://www.nagios.org/),
[Shinken](http://www.shinken-monitoring.org/), [Sensu](http://sensuapp.org/)
and other monitoring applications that uses Nagios style plugins.

It works well stand alone as well as via NRPE. Thresholds might be given as
arguments to the plugin or set globally in IoT Open Lynx as meta data on the
functions.

The plugin fetches the latest known value from Lynx and may use threshold for
alerting set either in the monitoring software or in Lynx as metadata on
functions.

## Prerequisites

You need an [API-Key](../../getstarted/api-access) to access your data in Lynx.

## Plugin syntax

```
$ ./check_lynx.sh -h
check_lynx v0.9

Monitor values of functions in IoT Open Lynx platform

Usage:
check_lynx -u <url> -k <api-key> -i <installation_id> -f <function_id> [ options ]

Options:
 -h, --help
    Print this help
 -u, --url
    URL to lynx, e.g. https://lynx.iotopen.se
 -k, --api-key
    API-Key to Lynx (get it from user profile in Lynx
 -i, --installation
    Installation id from Lynx
 -f, --function
    Function id from Lynx
 -a, --max-age
    Maximal age of the value in seconds. Renders CRITICAL if too old. (optional)
 -w, --warning
    Warning threshold (optional)
 -c, --critical
    Critical threshold (optional)
 -m, --min
    Minimal expected value
 -M, --man
    Maximal expected value

Thresholds:
The thresholds can be given as arguments or set as metadata in Lynx. They should
then have the same names as the long arguments. Like below:

max-age,warning,critical,min and max

If they are given both in Lynx and as parameters as above then the parameters will
be used.

If only critical or warning is set it will raise an alarm if higher or equal to 
the threshold.

If both warning and critical is used it will raise an alarm above or equal if 
critical is higher than warning and below if warning is higher than critical.

Min and max values:
The min and max values are only written in perfdata.

Questions:
Contact IoT Open at support@iotopen.se
```

## Thresholds

The thresholds may be set in Lynx as metadata with the same name as the long
option. Or given as parameters. The parameters have precedence over metadata in
Lynx.

If the max-age is set it will always render CRITICAL if the value is too old
according to its timestamp. This is good for alerting when some sensor stops
reporting or for some reason is offline.

## Metadata in Lynx the plugin uses

The plugin uses the following FunctionX metadata in Lynx:

| Metadata | Use | Example | Comment |
|----------|-----|---------|---------|
| name     | Naming output | Engine room temperature | |
| type     | Naming perfdata | humidity | |
| format  | Formatting output | %.1f | Printf format string (optional) |
| min      | Sent in perfdata | 0 | (optional) |
| max      | Sent in perfdata | 100 | (optional) |
| warning | Used as threshold | 30 | (optional) |
| critical | Used as threshold | 50 | (optional) |
| max\_age | Used as stale check | 600 | (optional) |

Se the help text above for explanation of thresholds.

## Test run the plugin

```
$ ./check_lynx -k 9a9044d698e0cbfe03e59d31f74e851f -u https://lynx.iotopen.se -w 40 -c 50 -i 1 -f 1          
Lynx WARNING: Engine Room Temperature: 43|temp=43;40;50;;

$ ./check_lynx -k 9a9044d698e0cbfe03e59d31f74e851f -u https://lynx.iotopen.se -i 1 -f 1 -w 50 -c 60
Lynx OK: Engine Room Temperature: 44|temp=44;50;60;;
```

