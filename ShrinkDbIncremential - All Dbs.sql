DECLARE @Sql VARCHAR(MAX)
DECLARE @DbName SYSNAME

DECLARE DbCursor CURSOR
FOR
    SELECT  name
    FROM    sys.databases
    WHERE   name NOT IN ('master','msdb','model','tempdb')
    ORDER BY name

OPEN DbCursor

FETCH NEXT FROM DbCursor INTO @DbName

WHILE @@FETCH_STATUS=0 
    BEGIN

		SET @Sql='USE ['+@DbName
		+']

		DECLARE @DBFileName sysname
		DECLARE @TargetFreeMB int
		DECLARE @ShrinkIncrementMB int
		DECLARE @EndSize INT
		DECLARE @CurSize INT
		DECLARE @SpaceUsed INT
		DECLARE @Sql VARCHAR(2000)
		DECLARE @StartTime DATETIME
		DECLARE @RunTime VARCHAR(5)
		DECLARE @FileName VARCHAR(255)
		DECLARE @Status NVARCHAR(500)
		DECLARE @SizeMB int
		DECLARE @UsedMB int

		-- Show Size, Space Used, Unused Space, and Name of all database files
		SELECT
			[FileSizeMB]	=
				CONVERT(numeric(10,2),ROUND(a.size/128.,2)),
			[UsedSpaceMB]	=
				convert(numeric(10,2),ROUND(FILEPROPERTY( a.name,''SpaceUsed'')/128.,2)) ,
			[UnusedSpaceMB]	=
				CONVERT(numeric(10,2),ROUND((a.size-FILEPROPERTY( a.name,''SpaceUsed''))/128.,2)) ,
			[DBFileName]	= a.name
		FROM sysfiles a

		DECLARE FileNameCursor CURSOR FOR 
		SELECT  a.name AS ''LogicalFileName''
			   ,(a.size*8)/1024 AS ''Size in MB''
			   ,ROUND((FILEPROPERTY(a.name,''SpaceUsed'')/128),0,0) as ''SpaceUsed in MB''
		FROM    dbo.sysfiles a
		INNER JOIN sysfilegroups b
		ON a.groupid=b.groupid

		OPEN FileNameCursor

		FETCH NEXT FROM FileNameCursor INTO @FileName, @CurSize, @SpaceUsed

		WHILE @@FETCH_STATUS = 0

		BEGIN

			IF @SpaceUsed BETWEEN 0 AND 1024
			SELECT @TargetFreeMB = 32

			IF @SpaceUsed BETWEEN 1025 AND 5000
			SELECT @TargetFreeMB = 96

			IF @SpaceUsed BETWEEN 5001 AND 10000
			SELECT @TargetFreeMB = 192

			IF @SpaceUsed > 10001
			SELECT @TargetFreeMB = 384

			-- Set Increment to shrink file by in MB
			SET @ShrinkIncrementMB = 150

			-- Set Name of Database file to shrink
			SET @DBFileName = @FileName

			-- Get current file size in MB
			SELECT @SizeMB = size/128. FROM sysfiles WHERE name = @DBFileName

			-- Get current space used in MB
			SELECT @UsedMB = FILEPROPERTY( @DBFileName,''SpaceUsed'')/128.

			SELECT [StartFileSize] = @SizeMB, [StartUsedSpace] = @UsedMB, [DBFileName] = @DBFileName

		-- Loop until file at desired size
			WHILE  @SizeMB > @UsedMB+@TargetFreeMB+@ShrinkIncrementMB
				BEGIN

					SET @sql =
					''DBCC SHRINKFILE ( [''+@DBFileName+''], ''+
					CONVERT(VARCHAR(20),@SizeMB-@ShrinkIncrementMB)+'' ) ''
								
					SET @Status =  ''Start '' + @sql
					RAISERROR (@Status, 0, 1) WITH NOWAIT
					SET @Status = ''at ''+convert(varchar(30),getdate(),121)
					RAISERROR (@Status, 0, 1) WITH NOWAIT				

					EXEC (@sql)
							
					SET @Status =  ''Done '' + @sql
					RAISERROR (@Status, 0, 1) WITH NOWAIT
					SET @Status = ''at ''+convert(varchar(30),getdate(),121)
					RAISERROR (@Status, 0, 1) WITH NOWAIT
				
					-- Get current file size in MB
					SELECT @SizeMB = size/128. from sysfiles where name = @DBFileName
	
					-- Get current space used in MB
					SELECT @UsedMB = FILEPROPERTY( @DBFileName,''SpaceUsed'')/128.

					SELECT [FileSize] = @SizeMB, [UsedSpace] = @UsedMB, [DBFileName] = @DBFileName

				END

			SELECT [EndFileSize] = @SizeMB, [EndUsedSpace] = @UsedMB, [DBFileName] = @DBFileName

			-- Show Size, Space Used, Unused Space, and Name of all database files
			SELECT
				[FileSizeMB]	=
					CONVERT(numeric(10,2),ROUND(a.size/128.,2)),
				[UsedSpaceMB]	=
					CONVERT(numeric(10,2),ROUND(fileproperty( a.name,''SpaceUsed'')/128.,2)) ,
				[UnusedSpaceMB]	=
					CONVERT(numeric(10,2),ROUND((a.size-fileproperty( a.name,''SpaceUsed''))/128.,2)) ,
				[DBFileName]	= a.name
			FROM 	sysfiles a
	
			FETCH NEXT FROM FileNameCursor INTO @FileName, @CurSize, @SpaceUsed

		END

		CLOSE FileNameCursor
		DEALLOCATE FileNameCursor	

		'

	--	PRINT @Sql
		EXEC (@Sql)

        FETCH NEXT FROM DbCursor INTO @DbName

    END

CLOSE DbCursor
DEALLOCATE DbCursor