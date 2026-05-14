PS:-
Skndash, jealous of his friend Yashwant's irresistible rizz, wants to hack his vaults and steal his Bashrots, that gift him the power of eternal aura. Unbeknownst to him, Yashwant has set up a robust vault and secured his bashrots extremely well. But he might have left a few threads hanging...

Note: There are commands for guards, bashers (players) and the warden (admin). All scripts should be placed in /scripts/ and added to the system PATH. Proper permissions must be implemented, so that only the respective group can execute their designated commands. For example, bashers should not be able to execute scripts restricted to the warden.

Parsing Requirement: The system relies on a YAML configuration file. You must use only yq for parsing. Do not use any third-party tools or libraries.

Write the bash scripts to implement the following:

Normal Mode
1) initRoster
Develop a script to automate user creation, environment injection, and directory structuring based on a given roster.yaml configuration file. The file contains lists of wardens, guards, and bashers, alongside an image URL for each.

Create system users and assign them to appropriate groups:
Players: bashers
Guards: guards
Wardens: wardens
Set up structured home directories:
Players: /home/bashers/<username> (must contain a Drop_Zone subdirectory)
Guards: /home/guards/<username>
Configure authentication & permissions:
Strictly disable password authentication for all the users in the "bashers" group. They must only be accessible via injected SSH public keys.
Bashers should only have access to their own home directories. Guards should have access to all bashers directories to monitor activity.
Generate ASCII avatars:
Parse the image URL from the roster, download it, and use a tool like jp2a to convert it to ASCII art.
This art should be saved as a hidden .avatar.txt file, and append a command to the user's .bashrc so it prints upon login.
Inject aliases:
Map at least 3 slang words (ex: cap, sus, mog) to actual Linux commands (ex: clear, ls, tail) and append these aliases to every basher's .bashrc to test their environment awareness.
Ensure the script dynamically updates the system when the warden runs the command after modifying the yaml file. If a user is removed, their access should be revoked, but their home directory should not be deleted.
2) secureVault
The bash rot must be contained. Write a script to build the vault and set up highly specific Access Control Lists (ACLs) on the host filesystem.

Create the secure vault: /opt/Bashrot_vault
Configure ACLs:
"guards" and "warden" group gets full rwx (read, write, execute) access.
"bashers" group is completely locked out (no read, write, execute).
Create the intentional vulnerability:
Inside the vault, create a hidden subdirectory.
Assign this subdirectory execute-only permissions for the "bashers" group, so that they can attempt to blindly navigate into it during the heist.
3) generateLore
This script acts as the cryptographic core. Instead of running manually, it must be designed to execute as a continuous background service process. Here's the catch: Yashwant's vault mechanism will jam if it processes cringe words.

The script must have read access to a file named slang.txt which contains a list of Gen Z slang terms.
Every 30 seconds, select exactly one random word from slang.txt and encode it using Base64.
The random word has to be selected after replacing a list of bad words with an asterisk of the same word length using sed command (stream editor).
Save the encoded string into a newly generated file and dump it into the secure vault directory.
4) collectTax
Bashers are known to hoard data. Write a script that acts as a ruthless storage enforcer (the Aura Tax) to manage server resources.

The script should check the storage size of every directory in the /home/bashers path.
If a basher has more than 5MB of data, automatically delete 3 of their oldest files.
Log deletions to a log file (in format as [TIMESTAMP] | BASHER_NAME | FILE_SIZE_IN_KB | FILE_NAME), accessible to only the users in the "guards" and "wardens" group.
Write a script for guards and wardens that uses awk to read the sanitized log, sum up the total FILE_SIZE_IN_KB for each specific basher, and output a clean leaderboard of who got taxed the most.
Write a single cron expression to run this script every 5 minutes, but only on Fridays and Saturdays.
5) verifyHeist
Develop a simple scoring engine script to detect if a basher has successfully bypassed the ACLs, decoded the Bashrot and stole the target. This script should only be executed by users in the "wardens" group.

Monitor the Drop_Zone directory of every basher. If a new file is dropped into the Drop_Zone directory, the script must detect this event and read the file contents.
Check if the contents match a decoded plain text word from slang.txt.
If valid, the script must broadcast a message to all users regarding the success of the basher and append the entry to heist.log along with metadata.
6) trendSetters
Develop a script that acts as a dynamic leaderboard engine to identify the current "trendsetters" among the bashers. This script should only be executable by users in the "wardens" group.

The script must compute scores for each basher based on recent activity and performance, and display the top 3 bashers at the time of execution.
In addition, it should indicate how many positions each basher has moved up or down compared to the previous leaderboard calculation (skip this comparison if no prior data exists).
Leaderboard results must be stored in a log file with appropriate ACLs, ensuring access is restricted to the "guards" and "wardens" groups.
Scoring should be derived from the following factors:
Streak: Identify the most active 5-minute window (valid heists only) for each basher within the last 24 hours, and scale it using a multiplier. This reflects peak performance during short bursts of activity.
Clutch Factor: The basher who most recently completed a valid heist at the time of computation should receive a significant bonus, emphasizing real-time dominance.
Decay Factor: Apply a logarithmic penalty to the score based on the time elapsed since the basher's last successful heist, ensuring that inactive users gradually drop in ranking.
The scoring system should be normalized relative to the number of active bashers to ensure fairness and consistency in rankings across different system sizes.
In cases where two bashers have identical scores, resolve ties based on more recent activity.
7) wipeTimeline
The warden needs a panic button to reset the entire simulation for the next round.

Terminate the generateLore background process.
Recursively wipe all files in each of the "bashers" directory, but keep the directories.
Wipe the Bashrot_Vault and reset ACLs back to their default secure state.
Super User Mode
1) The L Penalty
Snooping around should be any basher's trait, but snooping straight into what makes the hunt so great is penalizable for sure...

Create a penalty script that appends any harmful command that a basher tries to execute in a .txt file, under any Warden's subdirectory, with the username of the basher as the file name.
The script should parse the user's input against a predefined list of forbidden commands or regex patterns.
Design a penalty threshold, by assigning weights to the type of malicious commands that the basher tries to run.
Example: attempting to delete or modify system files will have the highest penalty weight, while attempting to ls or cd into a Warden's directory will be comparatively lesser.
When a user exceeds the penalty threshold, demote them to a rbash shell for 30 minutes, with commands restricted only to their specific bash aliases.
2) NoCap Security
The SysAds are up to no good, and they're already trying to break in. So why not beef up some security?

Write a script that generates exactly 6767 symlinks from the Bashrot_vault to random directories in the system.
Randomize the symlinks every 45 minutes.
Hide the real encoded file in an unknown directory as well.
Only the symlink pointing to the encoded file will be accepted as a valid victory.
