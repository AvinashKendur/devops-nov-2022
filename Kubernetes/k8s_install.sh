#!/bin/bash
kubeconfig_path=''
function unkown_option() {
echo -e "\nUnknown K8S node type: $1 \n"; 
echo "--------------------------------------------------------------------------"
echo "    This bash script will setup K8S cluster using kubeadm"
echo "       preffered Ubuntu 20.04_LTS with bellow requirement"
echo "       Master node:  minimum - 2GB RAM & 2Core CPU" 
echo "       Worker node:  Any"
echo "------------------------------ Master setup ------------------------------"
echo "    curl -s <url> | bash -s master"
echo "       Save the kubeadm join <token> command to run on worker node"
echo "------------------------------ Master setup ------------------------------"
echo "    curl -s <url> | bash -s worker"
echo "       Run the kubeadm join <token> command which we get from master node"
echo "--------------------------------------------------------------------------"
}

# Check if the machine Linux and Distor is Ubuntu or RHEL(RedHat)
UNAME=$(uname | tr "[:upper:]" "[:lower:]")
# If Linux, try to determine specific distribution
if [ "$UNAME" == "linux" ]; then
    # If available, use LSB to identify distribution
    if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
        kubeconfig_path='/home/ubuntu' 
    elif [[ -f /etc/redhat-release ]]; then
        kubeconfig_path='/home/ec2-user'
    else 
        echo -e "   Linux is not either Ubuntu nor RHEL.... \n"; 
        unkown_option
        exit 1; 
    fi  
else 
    echo -e "    Not a Linux platform ... \n"; 
    unkown_option
    exit 1; 
fi

[[ "$1" == "--help" || "$1" == "help" || "$1" == "-h" ]] && { unkown_option; exit 0;}

if [[ "$1" == 'master' ]]; then 
echo -e "\n-------------------------- K8S Master node setup --------------------------"
elif [[ "$1" == 'worker' ]]; then 
echo -e "\n-------------------------- K8S Worker node setup --------------------------"
else 
unkown_option $1
exit 1
fi

echo -e "\n-------------------------- Updating OS --------------------------\n"
sudo apt update
echo -e "\n-------------------------- APT transport for downloading pkgs via HTTPS --------------------------\n"
sudo apt-get install -y apt-transport-https

sudo su - <<EOF
echo -e "\n--------------------------  Adding K8S packgaes to APT list --------------------------\n"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list
EOF

echo -e "\n-------------------------- Installing docker.io --------------------------\n"
sudo apt update
sudo apt install -y docker.io

sudo su - <<EOF
echo -e "\n-------------------------- Updating container.io --------------------------\n"
wget -q https://github.com/containerd/containerd/releases/download/v1.6.12/containerd-1.6.12-linux-amd64.tar.gz
tar -xf containerd-1.6.12-linux-amd64.tar.gz
systemctl stop containerd
cd bin
cp * /usr/bin/
systemctl start containerd
EOF

echo -e "\n-------------------------- Starting and enabling docker.service --------------------------\n"
sudo systemctl start docker && echo "    Docker started"
sudo systemctl enable docker.service && echo "    docker.service enabled"

echo -e "\n-------------------------- Install kubeadm, kubelet, kubectl and kubernetes-cni --------------------------\n"
sudo apt-get install -y kubeadm kubelet=1.25.5-00 kubectl kubernetes-cni

if [[ "$1" == 'master' ]]; then 
echo -e "\n-------------------------- Initiating kubeadm (master node) --------------------------\n"
sudo su - <<EOF
kubeadm init
EOF
echo "--------------------------------------------------------------------------"
echo "       Save the above kubeadm join <token> command to run on worker node"
echo "--------------------------------------------------------------------------"
echo -e "\n-------------------------- Setiing-up Kubeconfig  --------------------------\n"
sleep 4
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
sudo chown $(id -u):$(id -g) $HOME/.kube/config
[[ -f "$HOME/.kube/config" ]] || echo "     Kubeconfig copied $HOME/.kube/config"

echo -e "\n-------------------------- Copy the join <token> command --------------------------\n" 
echo "    We need to run this command in the worker node which we need to add to this node "
echo "      1. (Better save the join command in a seperate file for future use )"
echo "      2. To generate new join command:  kubeadm token create --print-join-command"
echo -e "\n-----------------------------------------------------------------------------------\n"

echo -e "\n-------------------------- Install weaveworks network cni --------------------------\n"
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
#kubectl apply -f https://docs.projectcalico.org/manifests/calico-typha.yaml 

echo -e "\n---------------------------------- Checking mater node status ---------------------------\n"
kubectl get nodes
echo -e "\n Waiting to master node to get Ready ...........\n"
sleep 15
kubectl get nodes
echo
echo "    Note: wait to for 5-10 minutes, if node is still not in Ready state then try to install below calico network cni "
echo "          RUN: kubectl apply -f https://docs.projectcalico.org/manifests/calico-typha.yaml"
echo "          RUN: kubectl get nodes"
echo -e "\n-----------------------------------------------------------------------------------"
fi  

if [[ "$1" == 'worker' ]]; then 
sudo su -
echo "------------------------------------------------------------------------------------"
#echo "    switch to root user: sudo su -"
echo "    Allow incoming traffic to port 6443 in master node" 
echo "    Run the kubeadm join <TOKEN> command which we get from master"
#echo "    Run 'kubectl get nodes' on the control-plane to see this node joined the cluster."
echo "------------------------------------------------------------------------------------"
fi
