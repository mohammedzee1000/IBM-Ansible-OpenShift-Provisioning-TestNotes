# Testing Notes

1. If registry service needs to be available on lpar, then use `scripts/testing_utils/create_reg.sh` (modify values as needed) on the lpar. If its fresh lpar, make sure that the interface is up ie `3_setup_kvm_hosts.yaml` playbook has been completed. DO NOT use the master playbooks in this case.
2. Run the `scripts/testing_utils/prep_oc_mirror.sh` on http server. It is risky to build from source atm as it may fail but script for same is also provided `scripts/testing_utils/build-oc-mirror.sh`.
