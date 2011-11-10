#!/bin/bash

require "repo"
require "packagegroup"

header "Template"

# testing templates
TEMPLATE_NAME="template_$RAND"
TEMPLATE_NAME_2="template_2_$RAND"
test_success "template create" template create --name="$TEMPLATE_NAME" --description="template description" --org="$TEST_ORG"

test_success "template create with parent" template create --name="$TEMPLATE_NAME_2" --description="template 2 description" --parent="$TEMPLATE_NAME" --org="$TEST_ORG"
test_success "template update" template update --name="$TEMPLATE_NAME_2" --new_name="changed_$TEMPLATE_NAME_2" --description="changed description" --org="$TEST_ORG"

test_success "template list" template list --org="$TEST_ORG" --environment="Locker"

test_success "template update add product"                 template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_product="$FEWUPS_PRODUCT"
test_success "template update add package"                 template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package="cheetah"
test_success "template update add package using nvrea"                 template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package="lion-0.3-0.8.noarch.rpm"
test_success "template update add package group"           template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package_group="$PACKAGE_GROUP_NAME"
test_success "template update add package group categrory" template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package_group_category="$PACKAGE_GROUP_CATEGORY_NAME"
test_success "template update add parameter"                 template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_parameter="attr" --value="X"

test_success "template export in tdl"                 template export --name="$TEMPLATE_NAME" --org="$TEST_ORG" --format=tdl --file=template.out
test_success "template export in tdl"                 template export --name="$TEMPLATE_NAME" --org="$TEST_ORG" --format=tdl --file=template.out
test_success "template export in json"                template export --name="$TEMPLATE_NAME" --org="$TEST_ORG" --format=json --file=template.out
test_success "template export in json (default)"      template export --name="$TEMPLATE_NAME" --org="$TEST_ORG" --file=template.out
if [ -e template.out ] ; then rm template.out ; fi

test_success "template update remove parameter"              template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --remove_parameter="attr"
test_success "template update remove package group category" template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --remove_package_group_category="$PACKAGE_GROUP_CATEGORY_NAME"
test_success "template update remove package group"          template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --remove_package_group="$PACKAGE_GROUP_NAME"
test_success "template update remove package"              template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --remove_package="cheetah"
test_success "template update remove package using nvrea"              template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --remove_package="lion-0.3-0.8.noarch.rpm"
test_success "template update remove product"                template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --remove_product="$FEWUPS_PRODUCT"


test_failure "template update add unknown product" template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_product="does_not_exist"
test_failure "template update add unknown package" template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package="does_not_exist"
test_failure "template update add unknown product" template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package_group="does_not_exist"
test_failure "template update add unknown package" template update --name="$TEMPLATE_NAME" --org="$TEST_ORG" --add_package_group_category="does_not_exist"
