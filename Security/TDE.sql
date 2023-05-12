/* Transparent Database Encryption

Note: Backup/Restore won't be possible without certificate/key
*/
go

use master
go
create master key encryption by password = 'S0me$trongP@ssw0rd'
go
create certificate ProtectDataInRestCert with subject = 'Certificate for TDE'
go

use Credentials
go
create database encryption key with algorithm = aes_128
	encryption by server certificate ProtectDataInRestCert;
go
/* Warning: The certificate used for encrypting the database encryption key has not been backed up. You should immediately back up the certificate and the private key associated with the certificate. If the certificate ever becomes unavailable or if you must restore or attach the database on another server, you must have backups of both the certificate and the private key or you will not be able to open the database.
*/

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Backup Certificate & Master Key
---------------------------------------------------------------------------------------------
use master
go

backup master key to file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\my_laptop_master_key.key'
	encryption by password = 'S0me$trongP@ssw0rd';
go
backup certificate ProtectDataInRestCert
	to file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\ProtectDataInRestCert_certificate.crt'
	with private key (
		file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\ProtectDataInRestCert_private_key.pvk',
		encryption by password = 'S0me$trongP@ssw0rd'
	)
go

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Now enable encryption & simulate server failure
---------------------------------------------------------------------------------------------
use master
go
alter database Credentials set encryption on;
go

backup database Credentials to disk = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\Credentials.bak' with copy_only
go

use master
go
drop database Credentials
go
drop certificate ProtectDataInRestCert;
go
drop master key
go

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Test restore of database
---------------------------------------------------------------------------------------------
restore database Credentials /* Step 3 */
	from disk = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\Credentials.bak'
go
/* Msg 33111, Level 16, State 3, Line 67
Cannot find server certificate with thumbprint '0x87B58DC941C6AAAA4482A83A3849010678798F03'.
Msg 3013, Level 16, State 1, Line 67
RESTORE DATABASE is terminating abnormally.
*/

create certificate ProtectDataInRestCert /* Step 2 */
	from file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\ProtectDataInRestCert_certificate.crt'
	with private key (
		file = 'D:\GitHub-Personal\SQLDBA-SSMS-Solution\Sensitive\ProtectDataInRestCert_private_key.pvk',
		decryption by password = 'S0me$trongP@ssw0rd'
	);
go
/* Msg 15581, Level 16, State 1, Line 76
Please create a master key in the database or open the master key in the session before performing this operation.
*/

create master key encryption by /* Step 1 */
	password = 'S0meNew$trongP@ssw0rd'
go



