#!/bin/bash

help() {
    echo "This script installs/configures haproxy on an Ubuntu/Debian VM"
    echo "Options:"
    echo "        -a Backend application VM hostname (multiple allowed)"
    echo "        -p Backend application VM port (single, common for all application VMs)"
    echo "        -t Load balancer port"
}

while getopts ":a:p:l:t:m:b:h:" opt; do
    case $opt in
        a) 
          APPVMS+=("$OPTARG")
          ;;

        p) 
          APPVM_PORT="$OPTARG"
          ;;

        t) 
          LB_PORT="$OPTARG"
          ;;
		  
        \?) echo "Invalid option: -$OPTARG" >&2
          help
          ;;
    esac
done

setup_haproxy() {
    # Install haproxy
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:vbernat/haproxy-1.6
    apt-get update
    apt-get install -y haproxy    

    # Enable haproxy (to be started during boot)
    tmpf=`mktemp` && mv /etc/default/haproxy $tmpf && sed -e "s/ENABLED=0/ENABLED=1/" $tmpf > /etc/default/haproxy && chmod --reference $tmpf /etc/default/haproxy

    # Setup haproxy configuration file
    HAPROXY_CFG=/etc/haproxy/haproxy.cfg
    cp -p $HAPROXY_CFG ${HAPROXY_CFG}.default

    echo "
#-------------------------------------------------------------------------------
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    user        haproxy
    group       haproxy
    daemon
    maxconn     28000
    nbproc      1
    tune.ssl.default-dh-param   2048
    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats level admin
#-------------------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option                  http-server-close
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          10m
    timeout server          10m
    timeout http-keep-alive 10s
    timeout check           10s
#-------------------------------------------------------------------------------
frontend port-8080-in
    bind                    *:8080
    stats                   enable
    stats                   uri /haproxy?stats
#-------------------------------------------------------------------------------
frontend port-80-in
    bind                    *:80
    mode                    tcp
    option                  tcplog
    default_backend         iis-servers-port-80
backend iis-servers-port-80
    mode                    tcp
    balance                 roundrobin" > $HAPROXY_CFG
    # Add application VMs to haproxy listener configuration 
    #for APPVM in "${APPVMS[@]}"; do
    #    APPVM_IP=`host $APPVM | awk '/has address/ { print $4 }'`
    #    if [[ -z $APPVM_IP ]]; then
    #        echo "Unknown hostname $APPVM. Cannot be added to $HAPROXY_CFG." >&2
    #    else
    #        echo "    server $APPVM $APPVM_IP:$APPVM_PORT maxconn 5000 check" >> $HAPROXY_CFG
    #    fi 
    #done
echo "
   server                  app01   10.0.1.4:80 weight 1 check
   server                  app02   10.0.1.5:80 weight 1 check
#-------------------------------------------------------------------------------
listen  stats           127.0.0.1:8080
        mode            http
        log             global

        maxconn 10

        timeout client  30s
        timeout server  30s
        timeout connect 30s
        timeout queue   30s

        stats enable
        stats hide-version
        stats refresh 5s
        stats show-node
        stats auth admin:password
        stats uri  /haproxy?stats

" > $HAPROXY_CFG
	
    chmod --reference ${HAPROXY_CFG}.default

    # Start haproxy service
    service haproxy start

}

# Setup haproxy
setup_haproxy
