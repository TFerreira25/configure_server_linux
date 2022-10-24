#/bin/bash
read -p "Number of network intefaces: " placas
if [ $placas -eq "1" ]
then
	read -p "NAT interface name: " p_nat
	ip link set $p_nat up
	apt update
	apt upgrade -y
fi
if [ $placas -eq "2" ]
then
	read -p "NAT interface name: " p_nat
	read -p "Internal interface name: " p_internal
	ip link set $p_nat up
	ip link set $p_internal down
	printf 'Update your machine'
	spinner &
	apt update &> /dev/null
	apt upgrade -y
	sleep 10
	kill "$!"
	printf '\n'
	ip link set $p_nat down
	ip link set $p_internal up
fi
while [ "$opcao" != "0" ]
do
echo "*******************"
echo "*      Menu       *"
echo "*******************"
echo "* 1 - Static Ip 	*"
echo "* 2 - DNS         *"
echo "* 3 - DHCP        *"
echo "* 4 - Domain     	*"
echo "* 5 - SSH         *"
echo "* 6 - APACHE      *"
echo "* 7 - Openfire    *"
echo "* 8 - Rsyslog     *"
echo "* 9 - Samba       *"
echo "* 10 - NFS        *"
echo "* 11 - FTP        *"
echo "* 12 - Cockpit    *"
echo "* 13 - Asterisk   *"
echo "* 14 - Failover   *"
echo "*******************"
read opcao
clear
cd scripts/
case $opcao in
	"1")
		chmod +x ip_estatico.sh
		echo "Static ip config"
		cd /etc/netplan
		echo "How many network interfaces do you have? "
		read placas
		case $placas in
		"1")
			read -p "What is the name of your network inteface: " placa
			read -p "What IP do you want on this server: " ip
			echo "What netmask do you gonna use:"
			echo "Ex: 255.255.255.0 = /24"
			read -p "Bit Count (/24): " bitcount
			read -p "Gateway Ip of network: " gateway
			read -p "How many dns servers do you have on your network: " n_dns
			sed -i '3,$d' 00-installer-config.yaml
			if [ $n_dns -eq 1 ]
			then
				read -p "What is the dns ip: " ip
				total="$ip"
			elif [ $n_dns -gt 1 ]
			then
				for((i=1; i<=$n_dns;i++))
				do
					read -p "Dns IP Nº$i : " ip
					if [ $i -eq 1 ]
					then
						total="$ip"
					else
						total="$total,$ip"
					fi
				done
			fi
		echo "  ethernets:
			 $placa:
			   dhcp4: false
			   addresses: [$ip/$bitcount]
			   gateway4: $gateway
			   nameservers:
				addresses: [$total]
		  version: 2
		" >> 00-installer-config.yaml
		;;
		"2")
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			echo "Internal interface cofnig($p_internal)"
			read -p "Server IP: " ip_server
			echo "Subnet mask do you pretend:"
			echo "Exemple: 255.255.255.0 = /24"
			read -p "Bit Count: " bitcount
			read -p "Gateway Ip: " gateway
			read -p "How many dns servers do you have on your network: " n_dns
			sed -i '3,$d' 00-installer-config.yaml
			if [ $n_dns -eq 1 ]
			then
				read -p "What is the dns ip: : " ip_dns
				total="$ip_dns"
			elif [ $n_dns -gt 1 ]
			then
				for((i=1;i<=$n_dns;i++))
				do
					read -p "Dns IP Nº$i : " ip
					if [ $i -eq 1 ]
					then
						total="$ip"
					else
						total="$total,$ip"
					fi
				done
			fi
		#texto
		#texto
		echo "  ethernets:
			 $p_nat:
			   dhcp4: true
			 $p_internal:
			   dhcp4: false
			   addresses: [$ip/$bitcount]
			   gateway4: $gateway
			   nameservers:
				addresses: [$total]
		  version: 2
		" >> 00-installer-config.yaml
		;;
		esac
		netplan apply
		cat /etc/netplan/00-installer-config.yaml
	;;
	"2")
		echo "Configuração DNS"
		cd /
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq 1 ]
		then
			read -p "Network interface name: " placa
			ip link set $placa up
			apt install -y bind9 bind9utils
		elif [ $placas -eq 2 ]
		then
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			printf 'Instalação de pacotes necessários'
			spinner &
			apt install -y bind9 bind9utils &> /dev/null
			sleep 10
			kill "$!"
			printf '\n'
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		cd /etc/bind
		read -p "Introduza o dominio: " dominio
		echo "Introduza o IP do servidor"
		read -p "Enter the first octet of the IP (192.x.x.x): " ip1
		read -p "Enter the second octet of the IP (x.168.x.x): $ip1." ip2
		read -p "Enter the third octet of the IP (x.x.0.x): $ip1.$ip2." ip3
		read -p "Enter the fourth octet of the IP (x.x.x.1.): $ip1.$ip2.$ip3." ip4
		sed -i "/zone/,+50d" named.conf.local
		echo -e 'zone"'$dominio'" IN {
			type master;
			file "/etc/bind/forward.'$dominio'";
		};\n' >> named.conf.local
		echo -e 'zone "'$ip3.$ip2.$ip1.'in-addr.arpa" IN {
			type master;
			file "/etc/bind/reverse.'$dominio'";
		};\n' >> named.conf.local
		cp db.empty forward.$dominio
		cp db.empty reverse.$dominio
		echo "SERVER HOSTNAME: "
		hostname
		read -p "Hostname: " hostname
		sed -i "s/SOA	.*/SOA	$hostname.$dominio. root.$dominio. (/g" forward.$dominio
		sed -i "s/NS	.*/NS	$hostname./g" forward.$dominio
		echo "@	IN	A	$ip1.$ip2.$ip3.$ip4" >> forward.$dominio
		sed -i "s/SOA 	.*/SOA	$hostname.$dominio. root.$dominio. (/g" reverse.$dominio
		sed -i "s/NS	.*/NS	$hostname./g" reverse.$dominio
		echo "@	IN	PTR 	$ip1.$ip2.$ip3.$ip4" >> reverse.$dominio
		echo "$ip4	IN	PTR	$hostname." >> reverse.$dominio
		service bind9 restart
		ping -c 4 $dominio
		nslookup $dominio
		service bind9 status
	;;
	"3")
		echo "Configuração DHCP"
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq 1 ]
		then
			read -p "Nome da placa de rede: " placa
			ip link set $placa
			printf 'Package Installing'
			apt install -y isc-dhcp-server &> /dev/null
			printf '\n'
		elif [ $placas -eq 2 ]
		then
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			printf 'Package Installing'
			apt install isc-dhcp-server -y &> /dev/null
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		cd /etc/default/
		sed -i 's/v4=".*/v4="'$p_internal'"/g' isc-dhcp-server
		read -p "Domain Name: " dominio
		read -p "How many DNS: " n_dns
		cd /etc/dhcp/
		sed -i 's/option domain-name ".*/option domain-name "'$dominio'";/g' dhcpd.conf
		if [ $n_dns -eq 1 ]
		then
			read -p "DNS IP: " ip_dns
			sed -i 's/option domain-name-servers .*/option domain-name-servers '$ip_dns';/g' dhcpd.conf
		elif [ $n_dns -gt 1 ]
		then
			read -p "DNS IP: " dns
			for((i=0;i<$n_dns-1;i++))
			do
				read -p "DNS IP: " ip_dns
				dns="$dns, $ip_dns"
			done
			sed -i "s/option domain-name-servers .*/option domain-name-servers $dns;/g" dhcpd.conf
		fi
		read -p "Network ip: " ip_rede
		read -p "Netmask (EX: 255.255.255.0): " netmask
		read -p "First ip of the range: " ip_range_inicio
		read -p "Last ip of the range: " ip_range_fim
		read -p "Gateway IP: " gateway
		sed -i "/subnet /,+50d" dhcpd.conf
		echo "subnet $ip_rede netmask $netmask {
			range $ip_range_inicio $ip_range_fim;
			option routers $gateway;
		}" >> dhcpd.conf
		service isc-dhcp-server restart
		service isc-dhcp-server status
		cd /
	;;
	"4")
		echo "AD Domain Config"
		cd /
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq 1 ]
		then
			read -p "NAT interface name: " placa
			ip link set $placa up
			apt install -y ssh &> /dev/null
		elif [ $placas -eq 2 ]
		then
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			apt install -y ssh &> /dev/null
			rm -r pbis*
			wget https://github.com/BeyondTrust/pbis-open/releases/download/9.1.0/pbis-open-9.1.0.551.linux.x86_64.deb.sh
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		read -p "Windows server domain name: " dominio_windows
		read -p "Windows Server admin password: " -s password_windows
		chmod +x pbis-open-9.1.0.551.linux.x86_64.deb.sh
		./pbis-open-9.1.0.551.linux.x86_64.deb.sh
		cd /opt/pbis/bin
		domainjoin-cli join $dominio_windows Administrator $password_windows
		cd /
		/opt/pbis/bin/config UserDomainPrefix $dominio_windows
		/opt/pbis/bin/config AssumeDefaultDomain True
		/opt/pbis/bin/config LoginShellTemplate /bin/bash
		/opt/pbis/bin/config HomeDirTemplate %H/%D/%U
		domainjoin-cli join $dominio_windows Administrator $password_windows
		echo "Verify if the machine now on the domain"
		domainjoin-cli query
	;;
	"5")
		echo "SSH config"
		cd /
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq 1 ]
		then
			read -p "NAT interface name: " placa
			ip link set $placa up
		elif [ $placas -eq 2 ]
		then
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
		fi
		while [ "$escolha" != "1" ] && [ "$escolha" != "2" ]
		do
			read -p "Options:(1-Server/2-user): " escolha
		done
		case $escolha in
		"1")
			if [ $placas -eq "2" ]
			then
				apt install tightvncserver xfce4 xfce4-goodies
				ip link set $p_nat down
				ip link set $p_internal up
			fi
			vncpasswd
			cd /
			cd root/.vnc/
			touch xstartup
			chmod +x xstartup
		echo "#!/bin/sh
		unset SESSION_MANAGER
		unset DBUS_SESSION_BUS_ADDRESS
		startxfce4 &" >> xstartup
			ss -ltn
			sleep 5
			read -p "SSH port: " porta
			ufw allow from any to any port $porta proto tcp
			read -p "Do you want to run teh service(1-yes/2-no): " opcao
			if [ $opcao -eq 1 ]
			then
				echo "Start VNC"
				for((i=0;i<5;i++))
				do
					printf "."
					sleep 1
				done
				vncserver
			fi
		;;
		esac
	;;
	"6")
		echo "Apache config"
		cd /
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq "1" ]
		then
			read -p "NAT interface name: " placa
			ip link set $placa up
			apt install apache2
		elif [ $placas -eq "2" ]
		then
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			printf 'Package installing'
			apt install apache2 &> /dev/null
		fi
		ip link set $p_nat down
		ip link set $p_internal up
	;;
	"7")
		echo "Openfire config"
		cd /
		escolha=1
		while [ $escolha -gt 0 ] && [ $escolha -le 5 ]
		do
		escolha=10
		while [ $escolha -lt 0 ] || [ $escolha -gt 5 ]
		do
			echo "#####################################"
			echo "#         1-Instal Java             #"
			echo "#       2-Install Mysql Server      #"
			echo "#         3-Install Openfire        #"
			echo "#        4-Configure Openfire       #"
			echo "#      5-Install Spark(Client)      #"
			echo "#               0-Leave             #"
			echo "#####################################"
			read -p "Otion: " escolha
		done
		if [ $escolha -gt 0 ] && [ $escolha -le 5 ]
		then
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq 1 ]
		then
			read -p "NAT interface name: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq 2 ]
		then
			read -p "NAT interface name: " p_nat
			read -p "Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
		fi
		case $escolha in
			"1")
				cd /
				echo "installing java, wait a few seconds"
				apt install -y default-jre &> /dev/null
				clear
			;;
			"2")
				cd /
				echo "installing SQL SERVER, wait a few seconds"
				apt install -y mysql-server &> /dev/null
				clear
			;;
			"3")
				cd /
				echo "Do download of Openfire, wait a few seconds"
				wget -q https://www.igniterealtime.org/downloadServlet?filename=openfire/openfire_4.5.3_all.deb \-O openfire.deb
				dpkg -i openfire.deb &> /dev/null
				echo "Openfire instalado"
			;;
			"4")
				cd /
				echo "Service config"
				read -p "do you want to create a SQL SERVER user?(1-yes/2-nno): " cr_user
				if [ $cr_user -eq 1 ]
				then
					read -p "name of Mysql Server user: " nome_usr
					read -p "Password($nome_usr): " -s pass_usr
					echo "CREATE USER '$nome_usr'@'localhost' IDENTIFIED BY '$pass_usr';\nGRANT ALL PRIVILEGES ON *.* TO '$nome_usr'@'localhost';\nflush privileges;\ncreate database openfire;" | mysql -u root
				fi
				echo "Do you want to change openfire port (Default Port: 9090)"
				read -p "Option(1-yes/2-no): " opcao
				if [ $opcao -eq 1 ]
				then
					read -p "Port: " porta
					cd /etc/openfire/
					sed -i "s#<port>.*#<port>$porta</port>#g" openfire.xml
					sec_port=$(($porta+1))
					sed -i "s#<securePort>.*#<securePort>$sec_port</securePort>#g" openfire.xml
					for i in 5222 7777 $porta $sec_port; do sudo ufw allow $i; done
					cd /
				elif [ $opcao -eq 2 ]
				then
					cd /etc/openfire/
					sed -i "s#<port>.*#<port>9090</port>#g" openfire.xml
					sed -i "s#<securePort>.*#<securePort>9091<securePort>#g" openfire.xml
					for i in 5222 7777 9090 9091; do sudo ufw allow $i; done
					cd /
				fi
				echo "use openfire;\nsource /usr/share/openfire/resources/database/openfire_mysql.sql;\nshow tables;" | mysql -u root
				/etc/init.d/openfire status
				echo "to access you need yo insert on your web browser the ip you choose and port"
				echo "Ex: 192.168.0.2:9090"
				ip link set $p_nat down
				ip link set $p_internal up
			;;
			"5")
				cd /
				read -p "How many network interfaces do you have: " placas
				if [ $placas -eq 1 ]
				then
					read -p "NAT interface name: " p_nat
					ip link set $p_nat
				elif [ $placas -eq 2 ]
				then
					read -p "NAT interface name: " p_nat
					read -p "Internal interface name: " p_internal
					ip link set $p_nat up
					ip link set $p_internal down
				fi
				wget -p https://www.igniterealtime.org/downloadServlet?filename=spark/spark_2_9_4.tar.gz
				tar -xvf spark_2_9_4.tar.gz
				cd /Spark
				./Spark
				clear
			;;
		esac
		fi
		done
	;;
	"8")
		echo "Rsyslog Configuration"
		cd /
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq "1" ]
		then
			read -p "Network interface name: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq "2" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			read -p "wwhat is the name of your Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			apt install -y rsyslog
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		read -p "what system you want install(1-server/2-client): " opcao
		case $opcao in
		"1")
			cd /etc
			sed -i "17s/#//" rsyslog.conf
			sed -i "18s/#//" rsyslog.conf
			sed -i "21s/#//" rsyslog.conf
			sed -i "22s/#//" rsyslog.conf
			read -p "Quais a redes que pretende receber os logs: " n_log
			for((i=0;i<$n_log;i++))
			do
				read -p "Qual o ip da $i º rede: " ip
				read -p "Qual o barra dessa rede(Ex: /24 não 255.255.255.0): " bitcount
				total="$total, $ip/$bitcount"
			done
			sed -i "/AllowedSender TCP, .*/,+50d" rsyslog.conf
			echo "$""AllowedSender TCP, 127.0.0.1$total" >> rsyslog.conf
			echo '$template remote-incoming-logs, "/var/log/%HOSTNAME%/%PROGRAMNAME%.log"' >> rsyslog.conf
			echo "*.* ?remote-incoming-logs" >> rsyslog.conf
			echo "& ~" >> rsyslog.conf
			service rsyslog restart
			ss -tunelp | grep 514
			echo "Let's Apply the Rules to the Firewall"
			echo "Protocol TCP and UDP"
			ufw allow 514/tcp
			ufw allow 514/udp
			service restart rsyslog
			cd /
			cd /var/log
			ls
		;;
		"2")
			cd /etc
			echo "Qual o ip do servidor: "
			read ip_server
			echo "$""PreserveFQDN on" >> rsyslog.conf
			echo "*.* @ip_server:514" >> rsyslog.conf
			echo "$""ActionQueueFileName queue" >> rsyslog.conf
			echo "$""ActionQueueMaxSpace 1g" >> rsyslog.conf
			echo "$""ActionQueueSaveOnShutdown on" >> rsyslog.conf
			echo "$""ActionQueueType LinkedList" >> rsyslog.conf
			echo "$""ActionResumeRetryCount -1" >> rsyslog.conf
			service rsyslog restart
			cd /
			cd /var/log
		;;
		esac
	;;
	"9")
		echo "Configuração do Samba"
		read -p "Quantas placas tem a sua maquina local: " placas
		if [ $placas -eq "1" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq "2" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			read -p "Qual o Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			apt install -y samba
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		sed -i '242,$d' /etc/samba/smb.conf
		read -p "Qual o nome do utilizador que está logado atualmente: " user
		cd /home/$user
		read -p "Quantas pastas pretende criar: " num_pastas
		for((i=0;i<$num_pastas;i++))
		do
			read -p "Nome da Pasta ((i+1)): " n_pasta
			mkdir $n_pasta
			echo "Permissões:"
			echo "1-Leitura"
			echo "2-Escrita"
			read -p "Qual a permissão que deseja atribuir a pasta '$n_pasta': " opcao
			case $opcao in
			"1")
				chmod a=rx $n_pasta
			;;
			"2")
				chmod a=rxw $n_pasta
			;;
			esac
		echo "[$n_pasta]
		comment = samba
		path = /home/$user/$n_pasta" >> /etc/samba/smb.conf
			if [ $opcao -eq "1" ]
			then
				echo "guest ok = yes" >> /etc/samba/smb.conf
			else
				echo "writeable = yes" >> /etc/samba/smb.conf
			fi
			read -p "Existem utilizadores sem permissão para aceder a pasta(s-sim/n-não): " resposta
			if [ $resposta == "s" ] || [ $resposta == "S" ] || [ $reposta == "sim" ] || [ $reposta == "SIM" ]
			then
				read -p "Quantos utilizadores não poderão ter acesso: " numero_users
				if [ $numero_users -eq "1" ]
				then
					read -p "Qual o nome do utilizador: " nome_user
					echo "invalid users = $nome_user" >> /etc/samba/smb.conf
				else
					read -p "Qual o nome do utilizador: " nome_user
					total = $nome_user
					for((i=1;i<$numero_users-1;i++))
					do
						read -p "Insira outro nome de utilizador: " nome_user
						total="$total, $nome_user"
					done
					echo "invalid users = $total" >> /etc/samba/smb.conf
				fi
			else
				echo "Não introduzio nenhum utilizador"
			fi
		done
		read -p "Quantos utilizadores pretende que tenham acesso às pastas: " n_users
		for((i=0;i<$n_users;i++))
		do
			read -p "Qual o nome do utilizador: " nome_user
			smbpasswd -a $user
		done
		service smbd restart
		service nmbd restart
	;;
	"10")
		echo "Configuração NFS"
		read -p "Quantas placas de existem no server: " placas
		if [ $placas -eq "1" ]
		then
			read -p "Qual o Network interface name: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq "2" ]
		then
			read -p "Qual o NAT interface name: " p_nat
			read -p "Qual o Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			apt install -y nfs-kernel-server &> /dev/null
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		read -p "Quantas pastas pretende inserir: " pastas
		for((i=0;i<$pastas;i++))
		do
			cd /
			read -p "Insira o nome das pastas: " nome_p
			mkdir -m 777 $nome_p
			echo "Permissões:"
			echo "1-Ler"
			echo "2-Ler e Escrever"
			read -p "Qual a permissão da pasta que pretende: " opcao
			cd /etc
			case $opcao in
			"1")
				echo "/$nome_p 192.168.0.0/24(ro,no_subtree_check,sync)" >> exports
			;;
			"2")
				echo "/$nome_p 192.168.0.0/24(rw,no_subtree_check,sync)" >> exports
			;;
			esac
		done
		exportfs -av
		exportfs
	;;
	"11")
		echo "Configuração FTP"
		read -p "Quantas placas tem a sua maquina local: " placas
		if [ $placas -eq "1" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq "2" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			read -p "Qual o Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			apt install -y vsftpd &> /dev/null
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		cd /etc/
		sed -i "31s/#//" vsftpd.conf
		sed -i "99s/#//" vsftpd.conf
		sed -i "100s/#//" vsftpd.conf
		sed -i "122s/#//" vsftpd.conf
		sed -i "123s/#//" vsftpd.conf
		sed -i "125s/#//" vsftpd.conf
		sed -i "131s/#//" vsftpd.conf
		sed -i "/local_root=public_html/,+50d" vsftpd.conf
		echo "local_root=public_html

		seccomp_sandbox=NO" >> vsftpd.conf
		read -p "Quantos utilizadores serão colocados: " users
		for((i=0;i<$users;i++))
		do
			read -p "Insira o nome do utilizador: " nome
			echo "$nome" >> vsftpd.chroot_list
		done
		service vsftpd restart
		service vsftpd status
	;;
	"12")
		echo "Configuração do cokcpit"
		read -p "How many network interfaces do you have: " placas
		if [ $placas -eq "1" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq "2" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			read -p "Qual o Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			DEBIAN_FRONTEND=noninteractive apt install -y cockpit
			service cockpit restart
			echo "Serviço de cockpit instalado, acedo com o ip do servidor:9090"
			sleep 5
			ip link set $p_nat down
			ip link set $p_internal up
		fi
	;;
	"13")
		echo "Configuração do ASTERISK"
		read -p "Quantas placas na sua maquina local: " placas
		if [ $placas -eq "1" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			ip link set $p_nat up
		elif [ $placas -eq "2" ]
		then
			read -p "What is the name of your network inteface: " p_nat
			read -p "Qual o Internal interface name: " p_internal
			ip link set $p_nat up
			ip link set $p_internal down
			apt install -y asterisk &> /dev/null
			ip link set $p_nat down
			ip link set $p_internal up
		fi
		cd /etc/asterisk
		echo "[from-internal]" >> extensions.conf
		regcontext=100
		read -p "Quantos utilizadores irão utilizar o serviço telefónico: " extensoes
		for((c=0;c<$extensoes;c++))
		do
			read -p "Introduza o nome do utilizador: " user
			read -p "Introduza a password do utilizador($user): " -s password
			read -p "Pretende usar o voicemail ativo(s-sim/n-não): " opcao
			((regcontext++))
		echo "
		[$user]
		type=friend
		port=5060
		username=$user
		nat=yes
		qualify=yes
		regcontext=$regcontext
		context=from-internal" >> sip.conf
		echo "
		[$user]
		full name = $user
		secret = $password
		hassip = yes
		context = from-internal
		host = dynamic" >> users.conf
		echo "exten=>$user,1,Dial(SIP/$user,10)" >> extensions.conf
		if [ $opcao == "s" ] || [ $opcao == "S" ] || [ $opcao == "sim" ] || [ $opcao == "SIM" ]
		then
			echo "exten=>$user,2,Playback(vm-nobodyvail)" >> extensions.conf
		else
			echo "o utlizador não tem voice mail"
		fi
		done
		service asterisk restart
	;;
	"14")
		echo "Failover"
		cd /
		read -p "What is the name of your network inteface: " p_nat
		ip link set $p_nat down
		service bind9 stop
		service isc-dhcp-server stop
		read -p "Qual o ip do Windows Server presente na sua rede: " ip
		if [ $ip != "" ]
		then
			echo "$ip" > .windows_ip.txt
		fi
		while :
		do
			data=$(date +'%d-%m-%Y / %H:%M:%S')
			if ! ping -c 4 $(cat .windows_ip.txt) &> /dev/null
			then
				echo "[!] Windows Server não respondeu ao PING"
				echo "[!] Inicio do serviços do DHCP E DNS do ubuntuserver"
				echo "[!] $data --> Failover iniciado" >> /var/log/failover.log
				service bind9 start
				service bind9 restart
				service isc-dhcp-server start
				service isc-dhcp-server restart
			else
				echo "[!] Windows server respndeu ao ping"
				echo "[!] Fim do serviços de DHCP e DNS do ubuntuserver"
				echo "[!] $data --> Failover desligado" >> /var/log/failover.log
				service bind9 stop
				service isc-dhcp-server stop
			fi
		done
		read -p "Prentende tornar o failover um seriço (s-sim/n-não): " resposta
		echo "Qual a localização o ficheiro de failover: "
		read -p "Caminho: " path
		if [ $resposta == "s" ] || [ $resposta == "S" ] || [ $resposta == "sim" ] || [ $resposta == "SIM" ]
		then
			sed -i "s///" /projecto/scripts/failover.sh
			cd /lib/systemd/system
			touch failover.service
			sed -i '1,$d' failover.service
		echo "[Unit]
		After=netowrk.service

		[Service]
		ExecStart = $path

		[Install]
		WantedBy=default.target" >> failover.service
			chmod 644 failover.service
			chmod 744 $path
			service failover restart
			service failover status
		else
			echo "Não foi criado nenhum serviço"
		fi
	;;
esac
cd /projecto
done
