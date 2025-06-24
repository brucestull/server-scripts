

```bash
flynntknapp@DELL-DESK:~/Programming/server-scripts$ ./batch-shutdown-remote-servers.sh
➡️  Updating SPINAL-TAP.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating GRAVEL-ROAD.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating BLACK-RIDER.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating CLOSING-TIME.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating KITTY-MAGNUM.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
Shutdown scheduled for Mon 2025-06-23 14:41:45 EDT, use 'shutdown -c' to cancel.
➡️  Updating HORROR-POPS.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating FULL-MONTY.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
Shutdown scheduled for Mon 2025-06-23 14:41:50 EDT, use 'shutdown -c' to cancel.
➡️  Updating TAINT-NUTHIN.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating CACHE-FLOPPY.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating CHMOD-SNAFU.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required

📊 Update Summary
=================
✅ Succeeded (2):
  - KITTY-MAGNUM.lan
  - FULL-MONTY.lan

❌ Failed   (8):
  - SPINAL-TAP.lan
  - GRAVEL-ROAD.lan
  - BLACK-RIDER.lan
  - CLOSING-TIME.lan
  - HORROR-POPS.lan
  - TAINT-NUTHIN.lan
  - CACHE-FLOPPY.lan
  - CHMOD-SNAFU.lan

📝 Full details in ./shutdown-remote-servers-results.log
flynntknapp@DELL-DESK:~/Programming/server-scripts$ ./batch-
batch-cancel-shutdowns.sh         batch-rsync-remote-scripts.sh     batch-shutdown-remote-servers.sh  batch-update-remote-servers.sh
flynntknapp@DELL-DESK:~/Programming/server-scripts$ ./batch-cancel-shutdowns.sh
➡️  Updating SPINAL-TAP.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating GRAVEL-ROAD.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating BLACK-RIDER.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating CLOSING-TIME.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating KITTY-MAGNUM.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
System is going down. Unprivileged users are not permitted to log in anymore. For technical details, see pam_nologin(8).

Connection closed by 192.168.1.179 port 22
➡️  Updating HORROR-POPS.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating FULL-MONTY.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
System is going down. Unprivileged users are not permitted to log in anymore. For technical details, see pam_nologin(8).

Connection closed by 192.168.1.207 port 22
➡️  Updating TAINT-NUTHIN.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating CACHE-FLOPPY.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
➡️  Updating CHMOD-SNAFU.lan…
Pseudo-terminal will not be allocated because stdin is not a terminal.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required

📊 Update Summary
=================
✅ Succeeded (0):

❌ Failed   (10):
  - SPINAL-TAP.lan
  - GRAVEL-ROAD.lan
  - BLACK-RIDER.lan
  - CLOSING-TIME.lan
  - KITTY-MAGNUM.lan
  - HORROR-POPS.lan
  - FULL-MONTY.lan
  - TAINT-NUTHIN.lan
  - CACHE-FLOPPY.lan
  - CHMOD-SNAFU.lan

📝 Full details in ./shutdown-cancel-results.log
flynntknapp@DELL-DESK:~/Programming/server-scripts$
```
