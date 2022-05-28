use DBA_Admin
go

EXECUTE dbo.DatabaseBackup
			@Databases = '[RISK]',
			--@Databases = '[Accounts],[Adv_chart_Activation],[Bond],[CMS],[CTCL1.1],[Ebroking],[MIS],[MISC],[RISK],[ROLEMGM],[SBAudit],[SCCS],[SMS],[Test_db],[Testdb]',
			--@Databases = '[Accounts],[Adv_chart_Activation],[Bond],[CMS],[CTCL1.1],[Ebroking],[MIS],[MISC],[RISK],[ROLEMGM],[SBAudit],[SCCS],[SMS],[Test_db],[Testdb]',
			--@Databases = '[Accounts],[Adv_chart_Activation],[Bond],[CMS],[CTCL1.1],[Ebroking],[MIS],[MISC],[RISK],[ROLEMGM],[SBAudit],[SCCS],[SMS],[Test_db],[Testdb]',
			@Directory = '\\SomePathHere\D$\ServerNameHere\',
			@DirectoryStructure = '{DatabaseName}',
			@BackupType = 'FULL',
			--@NumberOfFiles = 2,
			@CopyOnly = 'Y',
			@Init = 'Y',
			@Verify = 'Y',
			@Compress = 'Y',
			@CheckSum = 'Y',
			--@CleanupTime = 24,
			@Execute = 'Y'
go


--exec xp_dirtree '\\172.31.2