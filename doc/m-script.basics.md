# General description


M-Script is a framework for infrastructure coding, configuration management and maintenance tasks automation. It contains a well-developed monitoring system that provides both valuable information about system status via alerts and reports and automation triggers which then can be used to initiate any sort of actions - from specific alerts to cloud-level automation (e.g. load grows high -> add more servers).


# Main features


* Easy configuration via plain text files.
* Easily scriptable Web interface.
* Database for storing monitoring data.
* Graphs generator.
* Cloud management and automation. Cross-cloud scripting, VM image formats conversion for easy VM transfer across different clouds.
* Cloud-like management of non-cloud groups of servers and combining cloud and non-cloud resources.
* Versatile and flexible backup system.
* Deployment system. Full infrastructure as code capabilities, hierarchical structure: single tasks can be executed independently or as part of a larger tasks, which in turn can be used to orchestrate any complex infrastructures.
* Monitoring system. Main monitors are built-in, custom monitors/plugins are very easy to create and add to the system. Supports 3 levels of alerts, basic historic data analysis and metrics change analysis (e.g. alerts for sudden or unusual change).
* Alert system. Allows recipient lists based on alert levels and functions (backups, monitoring etc). Multiple transports support.
* Programmable actions. This is the part allowing some simple logic applied to events to trigger an action: alert level, consequent events count, time passed etc, all can be ORed or ANDed.
* Tasks queue and locks manager. Repeats tasks, eliminates duplicates and so on.


# Configuration files


* conf/mon.conf           - the main configuration file (name is historical, maybe will be renamed one day), settings related to the system as a whole are there.
* nodes.list              - all nodes are listed in it along with a cluster they belong to and cloud they are located in. If nodes are located in a supported cloud, such nodes get listed automatically via cloud API, other nodes must be added manually. Manual and cloud-based nodes can be combined, this allows to combine cloud and non-cloud resources.
* conf/clusters.conf      - cluster in M-Script's terminology is a collection of identical nodes of the same role. Cluster can be a single node or a dynamically scalable collection of any size. This file defines essential attributes of nodes within a cluster, including size or VM configuration, role associated with the cluster, access details, image off of which this cluster nodes are built, location (region), network/firewall settings etc.
* conf/mail.alert.list    - recipients for alerts.
* conf/mail.admin.list    - recipients for reports and analytics.
* conf/mail.backup.list   - recipients for backup reports.
* conf/backup.conf        - default backup configuration. There also may be any number of custom configurations (see backup.run --configfiles=help).
* conf/backup.conf.list   - list of paths to backup (may not exist or be empty).
* conf/actions.conf       - programmable actions configuration: list of conditions with actions that are executed if the correspondent conditions are met.
* conf/dash.conf          - settings related to web UI.
* conf/deployment.conf    - settings for the deployment system.
* conf/clouds/*.conf      - cloud configurations. Each supported cloud has its template file in this folder. To enable a cloud, use its template file to create {yourcloudname}.conf. To enable a pseudo-cloud (a cloud made of any nodes not manageable via API), use any template with CLOUD_PROVIDER variable and all cloud-specific settings deleted.
* tests/*.conf            - configuration files of correspondent monitors, located in the same folder


# Executables


## Monitoring

* monitorload.run         - monitoring service (daemon)
* mon.run                 - main monitoring tool. It runs individual monitors and handles the output: saves data into database and sends alerts and reports. It is invoked periodically by monitorload service.

### Basic sequence monitors

Basic sequence monitors are monitors that run every $FREQ seconds (200 sec by default) on every node and that are included in BASIC_SEQUENCE (see conf/mon.conf). They monitor main system metrics and available out-of-box. They include:

* tests/mem.mon           - memory usage, load average, number of processes and uptime
* tests/cpu.mon           - cpu usage and frequency (if throttling is enabled)
* tests/disk.mon          - disks list, usage (space and inodes) and average i/o usage for all times and last $FREQ. Doesn't require disk list to be in the config, because is able to recognize mapped disks, symlinks, LV volumes etc
* tests/connections.mon   - open ports (TCP, UDP and Unix sockets) and number of connections established with each of them. Also number of connections per protocol and self-connection test
* tests/services.mon      - monitors services by their PID file, alerts if status of a service changes (service stops, starts, restarts). By default monitors /var/run, but any number of folders can be added. Removes stale PID files when runs (with issuing an alert).
* tests/bandwidth.mon     - in/out network bandwidth and total number of network connections
* tests/netstat.mon       - any network metrics, provided by Netstat utility. Most important metrics are pre-configured in tests/netstat.conf

### Additional monitors

Additional monitors are supposed to run when a special monitors execution mode is invoked. It is invoked when load average changes by more than THRESHOLD in FREQ seconds. The idea is that when load changes more dramatically than normal, it may mean that something is going on, so the extended set of monitors is executed to provide more information and help with analysis. It is also recommended to run this extended set periodically via Cron, with intervals 15-60 min.
Of course any of these monitors can be included into BASIC_SEQUENCE instead, if desired.
These are available out-of-box:

* tests/cpu_eaters.mon    - reports the most CPU-using processes, either single or collective (e.g. how much CPU is used by all Apache workers together)
* tests/memory_eaters.mon - same about memory
* tests/files.mon         - reports whether files have been changed since the last check. Often used in BASIC_SEQUENCE instead of extended set.
* tests/dmesg.mon         - shows last messages from the kernel
* tests/filesio.mon       - figures out what files are being read/written the most. This information is not readily available from the kernel, so the results are not always reliable, but helpful in most cases
* tests/filesize.mon      - finds out what files/folders grow the fastest
* tests/servers.mon       - checks connections with other servers. Often used to setup a mutual connection tests between servers within a project. Often used in BASIC_SEQUENCE. Able to check various ports over different protocols, see the config file for details.

### Other monitors

* tests/standalone_reports.mon - a pseudo-monitor useful to pass certain reports from standalone monitors (see below) to the main service.
* tests/time.mon          - able to check and fix clock of every server in a cluster or in the whole project. Useful when NTP services are not available or not wished.

### Standalone monitors

Some monitors do not fit well into the normal monitoring workflow. Mostly because they are more complex and not needed on every server (for example database monitors). Such monitors' results are not included into the main system report, they have their own reports, often multiple, in their own folders. They don't need mon.run and can be executed directly.
These are included into the basic tarball:

* standalone/Security: monitors SSH connections, detects and blocks (if so configured) brute force attacks, monitors processes based in /tmp and removes them (if configured)
* standalone/Clouds: monitors the cloud(s). Maintains the nodes list and reports about changes.


## Deployment system

It is a deployment, provisioning and maintenance tasks scripting central.

* deployment/metaexec     - executes tasks (a.k.a. metascripts) or individual scripts. With --newnode option creates a new node and runs the provided task on it.
* deployment/deploy_file  - generates a file from a template and places it onto the target node(s)
* deployment/deploy.run   - executes an individual script locally or remotely, normally invoked by metaexec
* deployment/message      - used to store the messages from individual scripts to show them after the task has finished, for use inside the scripts
* deployment/propvar      - used to propagate a variable's value across the scripts within a task, for use inside the scripts


## Helpers

A collection of helper scripts that can be used both manually and in the deployment system's scripts

* helpers/backup_monitoring_data  - backups all existing monitoring databases and starts over
* helpers/block_ip                - blocks IP address (with iptables)
* helpers/cknew                   - after M-Script update, shows the difference between old and new file (useful for configs)
* helpers/epoch2date              - converts Unix epoch time to default representation
* helpers/fetch                   - finds all available methods and uses one to fetch a file over Internet
* helpers/find_fd                 - lists all file descriptors opened by a process
* helpers/find_key                - finds an access key for a cluster or a node
* helpers/init_rc                 - populates rc folder (the extended set of monitors is configured using $M_ROOT/rc folder)
* helpers/localips                - lists local IPs
* helpers/logreader               - outputs the records from log file that appeared since the last check
* helpers/mountfile               - mounts a file as a disk
* helpers/mssh                    - a wrapper for ssh command. Finds the required SSH key, resolves name to IP if necessary. If a cluster is used as an argument, logs into the first server of the cluster
* helpers/remove_ip_from_firewall - removes IP address from iptables rules on multiple nodes
* helpers/sa_disable              - disables standalone monitor
* helpers/sa_enable               - enables standalone monitor (runs setup and copies its web interface files, if found)
* helpers/setvar                  - finds a variable by its name in M-Script's configs and sets its value
* helpers/setweb                  - sets various things for web interface (e.g. project's name to appear in the title)
* helpers/sslcert                 - convenient wrapper for openssl tool, easy way to generate CSR, self-signed certificates, hashed passwords, Apache's htpasswd etc
* helpers/trafeaters.sh           - finds network traffic eaters
* helpers/unblock_internal_connections - unblocks access for each node to all other nodes in the project in it's firewall
* helpers/unblock_ip              - unblocks IP address blocked by block_ip
* helpers/unnew                   - during M-Script's update, non-executable files that differ from the existing ones are saved with extension .new. This script copies new into old. Saves some typing.
* helpers/update_dns_serial       - used to update serial number of DNS zone file after edit
* helpers/upgrade.sh              - updates M-Script from repository or from the latest tarball
* helpers/wrapper                 - an easy way to make a service out of any program and create a Sysvinit rc file for it


## Cloud management

Most of the cloud-related executables that are in PATH, are wrappers located in cloud/common. When invoked, they check whether cloud is defined (via environment variable CLOUD or as option --cloud, or if role or cluster is set, default cloud for this role/cluster) and then call the executable of the same name for this cloud. If cloud is not defined, they cycle through all configured clouds.


* cloud/common/cloudexec          - executes a command remotely, on a single or multiple target nodes
* cloud/common/cloudsync          - copies file(s) to target node(s)
* cloud/common/cluster            - tool for work with clusters (list, show, configure etc)
* cloud/common/create_node        - creates new node
* cloud/common/destroy_node       - destroys node
* cloud/common/find_node          - finds a node via cloud API and checks if M-Script's records about this node are correct
* cloud/common/find_noncloud_node - emulates find_node for nodes that are not from a cloud
* cloud/common/get_ips            - lists IP addresses or host names of target node(s)
* cloud/common/node               - swiss knife tool for work with nodes, able to create, start, stop, restart, destroy, upgrade, clone etc. Exact functionality may depend on cloud
* cloud/common/save_node          - saves node into file
* cloud/common/show_flavors       - shows available node configurations (or sizes, or tariffs)
* cloud/common/show_images        - shows available images (custom images or distributions offered by provider)
* cloud/common/show_nodes         - lists nodes for a target with their details, also used to populate nodes.list and individual cloud lists
* cloud/common/show_noncloud_nodes - emulates show_nodes for non-cloud nodes
* cloud/common/update_hosts_file  - updates records about known nodes and their names in /etc/hosts
* cloud/common/update_mynetworks  - updates records about known nodes and their names in /etc/mynetworks (used for email communication within project and for some other things)
* cloud/common/update_nodes_list  - updates nodes.list using cloud API




