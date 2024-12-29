# YUM vs RPM

- INTRODUCTION:
    - This material focuses on understanding package managers in Linux, specifically how they help install and manage software efficiently on your system.

- Understanding Package Managers
    - Package managers, like YUM and RPM, are tools that simplify the installation of software on Linux systems. They help you install not just the software itself but also any other software it depends on.
    - RPM (Red Hat Package Manager) is used in CentOS, Red Hat, and Fedora, allowing you to install, uninstall, and query software packages using specific commands.

- The Role of YUM
    - YUM (Yellowdog Updater Modified) is a higher-level package manager that works on top of RPM. It automatically handles dependencies, making it easier to install software with a single command.
    - YUM searches software repositories, which are collections of software packages, to find and install the required software and its dependencies in the correct order.

- Managing Repositories
    - Repositories are configured in a specific directory, and you can view available repositories using the `yum repolist` command.
    - If the default repositories do not have the software you need, you can add additional repositories by following instructions usually provided with the software documentation.

- Reinforcing Learning
    - Practice using commands like `yum install`, `yum remove`, and `yum list` to manage packages effectively.
    - Engaging in hands-on labs will help solidify your understanding of how to work with package managers in Linux.

# Services in Linux

- INTRODUCTION
    - This material focuses on managing services in Linux, specifically how to configure software to run in the background, ensuring they start automatically and in the correct order after a reboot.

- Understanding Services in Linux
    - Services are background processes that need to be running continuously, such as web servers or database servers. They can be managed using commands like `systemctl` to start, stop, and check their status.
    - The `systemctl` command is the modern utility for managing services on a systemd-managed server, replacing older methods.

- Configuring a Program as a Service
    - To configure a program (e.g., a Python web server) as a service, create a systemd unit file in `/etc/systemd/system` with the appropriate directives, including `ExecStart` to specify how to run the application.
    - After creating the unit file, use `systemctl daemon-reload` to inform systemd of the new service, and then start it with `systemctl start <service_name>`.

- Automatic Startup and Additional Configurations
    - To ensure the service starts automatically at boot, configure the unit file with the `WantedBy` directive and enable it using `systemctl enable <service_name>`.
    - Additional configurations can include setting up dependencies, descriptions, and restart policies to enhance service management.

# Networking in linux
- INTRODUCTION
    - This material focuses on the foundational concepts of networking, including how devices communicate within and between networks, the role of switches and routers, and the configuration of routing tables in Linux systems.

- Understanding Networks
    - A network is formed when devices like computers are connected to a switch, allowing them to communicate with each other using assigned IP addresses.
The ip link command is used to view network interfaces, while the ip addr command assigns IP addresses to these interfaces.

- Role of Routers
    - Routers connect different networks, enabling communication between devices on separate networks by forwarding packets.
To reach another network, systems must be configured with a gateway, which acts as a door to the outside world.

- Routing Configuration
    - The route command displays the current routing table, and the ip route add command is used to add routes for communication between networks.
    - For internet access, a default gateway can be set, allowing devices to reach any unknown network through the router.

Here are some key commands used in this module related to networking and routing in Linux:

- **List and modify interfaces:**
  ```bash
  ip link
  ```
- **View assigned IP addresses:**
  ```bash
  ip addr
  ```
- **Assign an IP address to an interface:**
  ```bash
  ip addr add <IP_ADDRESS>/<SUBNET_MASK> dev <INTERFACE>
  ```
- **View the routing table:**
  ```bash
  route
  ```
- **Add a route to the routing table:**
  ```bash
  ip route add <DESTINATION_NETWORK> via <GATEWAY_IP>
  ```
- **Check if IP forwarding is enabled:**
  ```bash
  cat /proc/sys/net/ipv4/ip_forward
  ```
- **Enable IP forwarding:**
  ```bash
  echo 1 > /proc/sys/net/ipv4/ip_forward
  ```
- **Make IP forwarding persistent across reboots:**
  Modify the `/etc/sysctl.conf` file to include:
  ```bash
  net.ipv4.ip_forward = 1
  ```

# Domain Name Server
- INTRODUCTION
    - This material focuses on understanding DNS in Linux, including basic concepts, commands for exploring DNS configuration, and the transition from local host files to a centralized DNS server.

- Understanding DNS Configuration
    - In a small network, you can use the `/etc/hosts` file to map hostnames to IP addresses, allowing you to ping systems by name instead of IP.
    - When a hostname is not found in the local file, the system can be configured to use a DNS server for name resolution, which simplifies management as the network grows.

- DNS Server and Name Resolution
    - Each host has a configuration file (`/etc/resolv.conf`) where you specify the DNS server's IP address, allowing the host to resolve names through the DNS server.
    - The order of name resolution can be modified, allowing local entries to take precedence over DNS entries if needed.

- Domain Names and Structure
    - Domain names are structured hierarchically, with top-level domains (like .com, .net) and subdomains (like www) helping to organize and identify resources on the internet.
    - Organizations can create their own domain structures, and internal DNS servers can resolve these names, allowing for easier access within the organization.

                                Root Domain
                                │
                                ├── .com (Top-Level Domain)
                                │   ├── google.com
                                │   │   ├── www.google.com (Subdomain)
                                │   │   ├── maps.google.com (Subdomain)
                                │   │   ├── drive.google.com (Subdomain)
                                │   │   └── mail.google.com (Subdomain)
                                │   └── mycompany.com
                                │       ├── www.mycompany.com (Subdomain)
                                │       ├── mail.mycompany.com (Subdomain)
                                │       ├── drive.mycompany.com (Subdomain)
                                │       └── hr.mycompany.com (Subdomain)
                                │
                                ├── .net (Top-Level Domain)
                                │
                                ├── .edu (Top-Level Domain)
                                │
                                └── .org (Top-Level Domain)



Record Type	          Description	                                Example
A	                  Maps a domain name to an IPv4 address	    example.com. IN A 192.0.2.1
AAAA	              Maps a domain name to an IPv6 address	    example.com. IN AAAA 2001:db8::1
CNAME	              Canonical Name record;                      aliases one domain to another	www.example.com. IN CNAME example.com.
MX	                  Mail Exchange record;                       specifies mail servers for the domain	example.com. IN MX 10 mail.example.com.
TXT	                  Text record;                                used for various purposes, including verification	example.com. IN TXT "v=spf1 include:_spf.example.com ~all"
NS	                  Name Server record;                         specifies authoritative DNS servers for the domain	example.com. IN NS ns1.example.com.
PTR	                  Pointer record;                             maps an IP address to a domain name (reverse DNS)	1.2.0.192.in-addr.arpa. IN PTR example.com.
SRV	                  Service record;                             specifies services available for domain_sip._tcp.example.com. IN SRV 10 60 5060 sipserver.example.com.