#!/bin/bash

# EKS Access Entries - AWS CLI Implementation (FIXED VERSION)
# Replace YOUR_CLUSTER_NAME with your actual cluster name

CLUSTER_NAME="tenny-eks"

echo "=== EKS Access Entries Setup (Fixed) ==="
echo "Cluster: $CLUSTER_NAME"
echo ""

# Step 1: Check current authentication mode
echo "1. Checking current authentication mode..."
aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.accessConfig.authenticationMode' --output text
echo "Current mode: API_AND_CONFIG_MAP (Good - supports both methods)"
echo ""

# Step 2: Node group access entry already exists, skip
echo "2. Node group access entry already exists - skipping"
echo ""

# Step 3: Create Access Entry for User (Obed-Edom) - WITHOUT kubernetes-groups
echo "3. User Obed-Edom access entry already exists - skipping creation"
echo "Policy already associated successfully"
echo ""

# Step 4: Create Access Entry for GitHub Actions Role - WITHOUT kubernetes-groups
echo "4. Creating access entry for GitHub Actions role (without kubernetes-groups)..."
aws eks create-access-entry \
    --cluster-name $CLUSTER_NAME \
    --principal-arn "arn:aws:iam::768571909454:role/GitHubActionsRole" \
    --type STANDARD \
    --tags Name=github-actions-access

if [ $? -eq 0 ]; then
    echo "GitHub Actions access entry created successfully"
else
    echo "GitHub Actions access entry might already exist or there's an error"
fi
echo ""

# Step 5: Associate admin policy to GitHub Actions role
echo "5. Associating cluster admin policy to GitHub Actions role..."
aws eks associate-access-policy \
    --cluster-name $CLUSTER_NAME \
    --principal-arn "arn:aws:iam::768571909454:role/GitHubActionsRole" \
    --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
    --access-scope type=cluster

if [ $? -eq 0 ]; then
    echo "GitHub Actions policy association created successfully"
else
    echo "Policy association failed or already exists"
fi
echo ""

# Step 8: Verify all access entries
echo "8. Listing all access entries..."
aws eks list-access-entries --cluster-name $CLUSTER_NAME

echo ""
echo "9. Describing access policies for verification..."
aws eks list-associated-access-policies \
    --cluster-name $CLUSTER_NAME \
    --principal-arn "arn:aws:iam::768571909454:user/Obed-Edom"

aws eks list-associated-access-policies \
    --cluster-name $CLUSTER_NAME \
    --principal-arn "arn:aws:iam::768571909454:role/GitHubActionsRole"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Test access with the new configuration"
echo "2. Once confirmed working, you can switch to API-only mode:"
echo "   aws eks update-cluster-config --name $CLUSTER_NAME --access-config authenticationMode=API"
echo "3. Remove the old aws-auth ConfigMap:"
echo "   kubectl delete configmap aws-auth -n kube-system"
echo ""

# Optional: Commands to check status and troubleshoot
echo "=== Troubleshooting Commands ==="
echo ""
echo "Check cluster authentication mode:"
echo "aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.accessConfig'"
echo ""
echo "List all access entries:"
echo "aws eks list-access-entries --cluster-name $CLUSTER_NAME"
echo ""
echo "Get details of a specific access entry:"
echo "aws eks describe-access-entry --cluster-name $CLUSTER_NAME --principal-arn 'arn:aws:iam::768571909454:user/Obed-Edom'"
echo ""
echo "Test kubectl access:"
echo "kubectl auth can-i '*' '*' --as=Obed-Edom"
