# FILENAME ZIP in SAS

SAS macros that help to list the contents of ZIP files within your SAS session. [Details published in The SAS Dummy blog here.](https://blogs.sas.com/content/sasdummy/filename-zip-details/)

## ZIPpy details: a solution in three macros

Here's my basic approach to this problem:

First, create a list of all of the ZIP files in a directory and all of the file "members" that are compressed within.
I've already shared this technique in a previous article. Like an efficient (or lazy) programmer, I'm just reusing that work.
That's macro routine #1 (**%listZipContents**).

With this list in hand, iterate through each ZIP file member, "open" the file with FOPEN, and gather all of the available file attributes with FINFO.
I've divided this into two macros for readability. **%getZipMemberInfo** (macro routine #2) retrieves all of the file details for a single member and stores them in a data set.
**%getZipDetails** (macro routine #3) iterates through the list of ZIP file members,
calls %getZipMemberInfo on each, and concatenates the results into a single output data set.
