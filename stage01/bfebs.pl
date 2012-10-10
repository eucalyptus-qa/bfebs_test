#!/usr/bin/perl

require "ec2ops.pl";

my $account = shift @ARGV || "eucalyptus";
my $user = shift @ARGV || "admin";

# need to add randomness, for now, until account/user group/keypair
# conflicts are resolved

$rando = int(rand(10)) . int(rand(10)) . int(rand(10));
if ($account ne "eucalyptus") {
    $account .= "$rando";
}
if ($user ne "admin") {
    $user .= "$rando";
}
$newgroup = "bfebsgroup$rando";
$newkeyp = "bfebskey$rando";

parse_input();
print "SUCCESS: parsed input\n";

setlibsleep(2);
print "SUCCESS: set sleep time for each lib call\n";

setremote($masters{"CLC"});
print "SUCCESS: set remote CLC: masterclc=$masters{CLC}\n";

discover_emis();
print "SUCCESS: discovered loaded image: current=$current_artifacts{instancestoreemi}, all=$static_artifacts{instancestoreemis}\n";

discover_zones();
print "SUCCESS: discovered available zone: current=$current_artifacts{availabilityzone}, all=$static_artifacts{availabilityzones}\n";

if ( ($account ne "eucalyptus") && ($user ne "admin") ) {
# create new account/user and get credentials
    create_account_and_user($account, $user);
    print "SUCCESS: account/user $current_artifacts{account}/$current_artifacts{user}\n";
    
    grant_allpolicy($account, $user);
    print "SUCCESS: granted $account/$user all policy permissions\n";
    
    get_credentials($account, $user);
    print "SUCCESS: downloaded and unpacked credentials\n";
    
    source_credentials($account, $user);
    print "SUCCESS: will now act as account/user $account/$user\n";
}
# moving along

add_keypair("$newkeyp");
print "SUCCESS: added new keypair: $current_artifacts{keypair}, $current_artifacts{keypairfile}\n";

add_group("$newgroup");
print "SUCCESS: added group: $current_artifacts{group}\n";

authorize_ssh();
print "SUCCESS: authorized ssh access to VM\n";

run_instances(1, 0);
print "SUCCESS: ran instance: $current_artifacts{instance}\n";

wait_for_instance();
print "SUCCESS: instance went to running: $current_artifacts{instancestate}\n";

wait_for_instance_ip();
print "SUCCESS: instance got public IP: $current_artifacts{instanceip}\n";

wait_for_instance_ip_private();
print "SUCCESS: instance got private IP: $current_artifacts{instanceprivateip}\n";

ping_instance_from_cc($current_artifacts{instanceprivateip}, "y", 0);
print "SUCCESS: instance private IP pingable from CC: instanceip=$current_artifacts{instanceprivateip} ccip=$current_artifacts{instancecc}\n";
sleep(30);

create_volume(2);
print "SUCCESS: created volume: vol=$current_artifacts{volume}\n";

wait_for_volume();
print "SUCCESS: volume became available: vol=$current_artifacts{volume}, volstate=$current_artifacts{volumestate}\n";

attach_volume();
print "SUCCESS: attached volume: volstate=$current_artifacts{volumestate}\n";

wait_for_volume_attach();
print "SUCCESS: volume became attached: volstate=$current_artifacts{volumestate}\n";

find_instance_volume();
$idev = $current_artifacts{instancedevice};
print "SUCCESS: discovered instance local EBS dev name: $idev\n";

setbfeimagelocation("http://mirror.qa.eucalyptus-systems.com/bfebs-image/vmware/bfebs_vmwaretools.img");
print "SUCCESS: Changed BFEBS URL: $bfe_image\n";

populate_volume_with_image();
print "SUCCESS: splatted image on volume\n";

detach_volume();
print "SUCCESS: detached volume\n";

wait_for_volume_detach();
print "SUCCESS: volume became detached: volstate=$current_artifacts{volumestate}\n";

create_snapshot();
print "SUCCESS: created snapshot: snap=$current_artifacts{snapshot}\n";

settrycount(3600);

wait_for_snapshot();
print "SUCCESS: snapshot became available: snap=$current_artifacts{snapshotstate}\n";

settrycount(180);

register_snapshot();
print "SUCCESS: registered new BFEBS image: emi=$current_artifacts{ebsemi} snap=$current_artifacts{snapshot}\n";

terminate_instances();

sleep(30);

setemitype("ebsemi");
print "SUCCESS: set emitype to 'ebsemi'\n";

run_instances(1, 1);
print "SUCCESS: ran instance: $current_artifacts{instance}\n";

wait_for_instance();
print "SUCCESS: instance went to running: $current_artifacts{instancestate}\n";

wait_for_instance_ip();
print "SUCCESS: instance got public IP: $current_artifacts{instanceip}\n";

wait_for_instance_ip_private();
print "SUCCESS: instance got private IP: $current_artifacts{instanceprivateip}\n";

setpingtries(420);
ping_instance_from_cc($current_artifacts{instanceprivateip}, "n", 1);
print "SUCCESS: instance private IP pingable from CC: instanceip=$current_artifacts{instanceprivateip} ccip=$current_artifacts{instancecc}\n";

#commented out until BFEBS images support ssh from the QA testers
#run_instance_command("shutdown -H now");

stop_instance();

wait_for_stopped_instance();

start_instance();

wait_for_instance();
print "SUCCESS: instance went to running: $current_artifacts{instancestate}\n";

wait_for_instance_ip();
print "SUCCESS: instance got public IP: $current_artifacts{instanceip}\n";

wait_for_instance_ip_private();
print "SUCCESS: instance got private IP: $current_artifacts{instanceprivateip}\n";

setpingtries(420);
ping_instance_from_cc($current_artifacts{instanceprivateip}, "n", 1);
print "SUCCESS: instance private IP pingable from CC: instanceip=$current_artifacts{instanceprivateip} ccip=$current_artifacts{instancecc}\n";

doexit(0, "EXITING SUCCESS\n");
