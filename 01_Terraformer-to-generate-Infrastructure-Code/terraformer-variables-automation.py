import os
import sys
import logging

logging.basicConfig(level=logging.INFO)

try:
    print("Please enter the following inputs")
    provider = input('Enter the provider: ')
    region = input('Enter the region: ')
    resource = input('Enter the resource name: ')
    string_add_variable = 'terraformer import ' + provider + ' --resources=' + resource + ' --regions=' + region
    os.system(string_add_variable)
except Exception as e:
    print("terraformer command not found:", e)

# Prompt user for input
resource_name = input("Enter the name of the resource you want to automate: ")
base_dir = os.getcwd()
final_path = os.path.join(base_dir, 'generated', 'aws', resource_name)

# Check if the directory exists
if not os.path.isdir(final_path):
    print("Directory does not exist:", final_path)
    sys.exit(1)

os.chdir(final_path)
os.system('ls -l')

final_file = input("Enter the name of the file you want to variablize (with .tf extension): ")
final_path2 = os.path.join(base_dir, 'generated', 'aws')
os.chdir(final_path2)
os.system('mkdir -p module')

final_path3 = os.path.join(base_dir, 'generated', 'aws', 'module')
os.chdir(final_path3)
os.system("mkdir -p " + resource_name)

def create_module():
    with open(base_dir + '/generated/aws/module/' + resource_name + '/resource.tf', 'w') as f:
        f.write(f'module "{resource_name}" {{ \n source = "../../{resource_name}" \n }}')

create_module()

def identify1(line):
    replace_string = "default = " + line.split('=')[1].strip()
    return replace_string

def replace1(replace_string, var, i):
    with open(base_dir + '/generated/aws/module/' + resource_name + '/variable.tf', 'r') as file:
        data = file.read()
        data = data.replace(f'default = "{var}{i}"', replace_string + "\n")

    with open(base_dir + '/generated/aws/module/' + resource_name + '/variable.tf', 'w') as file:
        file.write(data)

def variable(var, i):
    with open(base_dir + '/generated/aws/module/' + resource_name + '/variable.tf', 'a') as f:
        f.write(f'variable "{var}{i}" {{ \n default = "{var}{i}" \n}}\n')

file = open(base_dir + '/generated/aws/' + resource_name + '/' + final_file).readlines()

def identify(line):
    replace_string = line.split('=')[1].strip()
    return replace_string

def replace(replace_string, var, i):
    with open(base_dir + '/generated/aws/' + resource_name + '/' + final_file, 'r') as file:
        data = file.read()
        data = data.replace(replace_string, f' var.{var}{i}\n')
    with open(base_dir + '/generated/aws/' + resource_name + '/' + final_file, 'w') as file:
        file.write(data)

def create_var(var, i):
    with open(base_dir + '/generated/aws/' + resource_name + '/variables.tf', 'a') as f:
        f.write(f'variable "{var}{i}" {{  }}\n')

def modify_modules(var, i):
    with open(base_dir + '/generated/aws/module/' + resource_name + '/resource.tf', 'a') as f:
        f.write(f'{var}{i} = var.{var}{i}\n ')

def closure():
    with open(base_dir + '/generated/aws/module/' + resource_name + '/resource.tf', 'a') as f:
        f.write('}')

# Define the resource-specific variables
if resource_name == "ec2_instance":
    var_list = ['ami', 'instance_type', 'vpc_id', 'cidr_block', 'subnet_id', 'availability_zone']
elif resource_name == "vpc":
    var_list = ['assign_generated_ipv6_cidr_block', 'cidr_block', 'instance_tenancy', 'Name']
elif resource_name == "subnet":
    var_list = ['cidr_block', 'Name', 'vpc_id']
elif resource_name == "ebs":
    var_list = ['availability_zone', 'size', 'type']
elif resource_name == "rds":
    var_list = ['subnet_ids']
elif resource_name == "cloudwatch":
    var_list = ['description', 'event_pattern', 'name']
else:
    var_list = []

replacements = []
i = 1
for var in var_list:
    for line in file:
        if var in line:
            replace_string = identify1(line)
            variable(var, i)
            replace1(replace_string, var, i)
            replace_string = identify(line)
            replace(replace_string, var, i)
            modify_modules(var, i)
            create_var(var, i)
            i += 1
            replacements.append(var)

closure()
print('Attributes replaced:', replacements)
