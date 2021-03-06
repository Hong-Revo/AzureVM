context("VM scaleset connection pool")

tenant <- Sys.getenv("AZ_TEST_TENANT_ID")
app <- Sys.getenv("AZ_TEST_APP_ID")
password <- Sys.getenv("AZ_TEST_PASSWORD")
subscription <- Sys.getenv("AZ_TEST_SUBSCRIPTION")

if(tenant == "" || app == "" || password == "" || subscription == "")
    skip("Tests skipped: ARM credentials not set")

vmss_name <- paste0("vmss", paste0(sample(letters, 10, TRUE), collapse=""))
location <- "australiaeast"

maxpoolsize <- options(azure_vm_maxpoolsize=10)

rg <- AzureRMR::az_rm$
    new(tenant=tenant, app=app, password=password)$
    get_subscription(subscription)$
    create_resource_group(vmss_name, location)

test_that("Scaleset connection pool works",
{
    vm <- rg$create_vm_scaleset(vmss_name, user_config("username", "../resources/testkey.pub"), instances=5,
        autoscaler=NULL, load_balancer=NULL)
    expect_is(vm, "az_vmss_template")

    # sometimes deployment will return prematurely
    Sys.sleep(5)

    inst <- vm$list_instances()
    expect_is(inst, "list")
    expect_length(inst, 5)

    vm$run_script("ls /tmp", id=names(inst)[1:2])
    expect_identical(pool_size(), 2L)

    expect_silent(vm$get_vm_private_ip_addresses(names(inst[1:2])))
    expect_silent(vm$get_vm_private_ip_addresses(inst[1:2]))

    vm$get_vm_private_ip_addresses()
    expect_identical(pool_size(), 5L)

    expect_silent(vm$get_vm_private_ip_addresses(inst))
    expect_silent(vm$get_vm_private_ip_addresses(inst[[1]]))

    delete_pool()
    expect_false(pool_exists())
})

rg$delete(confirm=FALSE)
options(maxpoolsize)

