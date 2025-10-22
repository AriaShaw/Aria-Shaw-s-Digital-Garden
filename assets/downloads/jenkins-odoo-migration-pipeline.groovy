pipeline {
    agent any

    parameters {
        choice(name: 'MIGRATION_TYPE', choices: ['assessment', 'backup', 'migration', 'rollback'], description: 'Type of migration operation')
        string(name: 'DATABASE_NAME', defaultValue: 'production_db', description: 'Source database name')
        string(name: 'TARGET_VERSION', defaultValue: '17.0', description: 'Target Odoo version')
    }

    stages {
        stage('Pre-Migration Assessment') {
            when {
                expression { params.MIGRATION_TYPE == 'assessment' }
            }
            steps {
                script {
                    sh '''
                        cd /opt/migration-toolkit
                        ./scripts/migration_assessment.sh --database ${DATABASE_NAME} --target-version ${TARGET_VERSION}
                    '''
                }
            }
        }

        stage('Create Backup') {
            when {
                expression { params.MIGRATION_TYPE == 'backup' }
            }
            steps {
                script {
                    sh '''
                        cd /opt/migration-toolkit
                        ./scripts/enterprise_backup.sh --database ${DATABASE_NAME} --verify-restore
                    '''
                }
            }
        }

        stage('Execute Migration') {
            when {
                expression { params.MIGRATION_TYPE == 'migration' }
            }
            steps {
                script {
                    sh '''
                        cd /opt/migration-toolkit
                        ./scripts/zero_downtime_migration.sh --source-db ${DATABASE_NAME} --target-version ${TARGET_VERSION}
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'logs/**/*', fingerprint: true
            emailext body: "Migration ${params.MIGRATION_TYPE} completed for ${params.DATABASE_NAME}",
                     subject: "Odoo Migration Status: ${currentBuild.result}",
                     to: "migration-team@company.com"
        }
    }
}