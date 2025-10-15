pipeline {
    agent any 
    
    environment {
        SCANNER_HOME = tool "sonar-scanner"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        HARBOR_HOST = "10.0.0.5:30002"
        IMAGE_NAME = "tripsplitter/tripapp"
        HARBOR_PROJECT = "tripsplitter"
    }
    
    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git', url: 'https://github.com/echuwok12/TripSplitter'
            }
        }
        
        stage('Gitleaks Secret Scan') {
            steps {
                script {
                    sh '''
                    gitleaks detect --source . --no-banner --exit-code 1 --report-path gitleaks-report.json
                    '''
                }
            }
        }
        
        stage('Install Dependecies') {
            steps {
                sh 'npm install'
            }
        }
        
        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs --format table -o fs-report.html .'
            }
        }
        
        stage('SonarQube') {
            steps {
                withSonarQubeEnv('SonarQube') {  
                    sh """
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=TripSplitter \
                        -Dsonar.projectName=TripSplitter \
                        -Dsonar.sources=.
                    """
                }
            }
        }
        
        stage('Quality Gate SonarQube') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }
        
        stage('Docker Image Build & Tag') {
            steps {
                script {
                        // Build Docker image with environment variables as build arguments
                        sh """
                            docker build \
                            --build-arg DB_HOST=$DB_HOST \
                            --build-arg DB_USER=$DB_USER \
                            --build-arg DB_PASSWORD=$DB_PASSWORD \
                            --build-arg DB_NAME=$DB_NAME \
                            -t ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG} .
                        """
                }
            }
        }
        
        stage('Login to Harbor') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'harbor-cred', usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')]) {
                    sh 'docker login ${HARBOR_HOST} -u ${HARBOR_USER} -p ${HARBOR_PASS}'
                }
            }
        }

        stage('Push Image') {
            steps {
                sh """
                docker push ${HARBOR_HOST}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
        }
        
        post {
            always {
                script {
                    def jobName = env.JOB_NAME
                    def buildNumber = env.BUILD_NUMBER
                    def pipelineStatus = currentBuild.result ?: 'UNKNOWN'
                    def bannerColor = pipelineStatus.toUpperCase() == 'SUCCESS' ? 'green' : 'red'
        
                    def body = """
                        <html>
                        <body>
                            <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                                <h2>${jobName} - Build ${buildNumber}</h2>
                                <div style="background-color: ${bannerColor}; color: white; padding: 5px;">
                                    <h3>Status: ${pipelineStatus.toUpperCase()}</h3>
                                </div>
        
                                <p>Check the Jenkins <a href="${BUILD_URL}">console output</a> for more details.</p>
                            </div>
                        </body>
                        </html>
                    """
        
                    emailext(
                        subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus}",
                        body: body,
                        to: "duylinh2904@gmail.com",
                        from: "",
                        replyTo: "",
                        mimeType: 'text/html'
                    )
                }
            }
        }
    }
}
