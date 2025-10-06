pipeline {
    agent any

    tools {
        nodejs 'node18'
    }

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        DEPLOY_PATH = "deploy/tripapp"
        IMAGE = "harbor.duckdns.org/tripsplitter/tripapp"
        IMAGE_TAG = "v${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', credentialsId: 'git', url: 'https://github.com/echuwok12/SplitPayment'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('Run Tests') {
            steps {
                sh 'npm test'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs --format table -o fs-report.html . || true'
            }
        }

        stage('SonarQube Scan') {
            steps {
                withSonarQubeEnv('sonar-token') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectName=TripApp \
                        -Dsonar.projectKey=TripApp \
                        -Dsonar.sources=.
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build App') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Docker Build & Tag') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'harbor-cred', url: 'https://harbor.duckdns.org') {
                        sh "docker build -t ${IMAGE}:${IMAGE_TAG} -f Dockerfile ."
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "trivy image --format table -o image-report.html ${IMAGE}:${IMAGE_TAG} || true"
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'harbor-cred', url: 'https://harbor.duckdns.org') {
                        sh "docker push ${IMAGE}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Update CD Repo Manifest') {
            steps {
                script {
                    cleanWs()
                    withCredentials([usernamePassword(
                        credentialsId: 'git-cred',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh '''
                            git clone https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/echuwok12/SplitPayment-CD.git cd-repo
                            cd cd-repo/${DEPLOY_PATH}

                            # Update deployment image tag
                            echo "Updating image tag to ${IMAGE}:${IMAGE_TAG}"
                            yq -i ".spec.template.spec.containers[0].image = \\"${IMAGE}:${IMAGE_TAG}\\"" manifest.yaml

                            git config user.email "jenkins@ci.com"
                            git config user.name "Jenkins"
                            git add deployment.yaml
                            git commit -m "CI: Update image tag to ${IMAGE_TAG}" || echo "No changes to commit"
                            git push origin main
                        '''
                    }
                }
            }
        }

        stage('Deploy to AKS') {
            steps {
                script {
                    sh '''
                        echo "Deploying updated manifests to AKS..."
                        kubectl apply -f cd-repo/${DEPLOY_PATH}/ -n tripapp
                        kubectl rollout status deployment/tripapp -n tripapp || true
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                def jobName = env.JOB_NAME
                def buildNumber = env.BUILD_NUMBER
                def pipelineStatus = currentBuild.result ?: 'UNKNOWN'
                def bannerColor = (pipelineStatus == 'SUCCESS') ? 'green' : 'red'

                def body = """
                    <html>
                    <body>
                        <div style='border:3px solid ${bannerColor}; padding:10px;'>
                            <h2>${jobName} - Build #${buildNumber}</h2>
                            <div style='background-color:${bannerColor}; color:white; padding:5px;'>
                                <h3>Status: ${pipelineStatus}</h3>
                            </div>
                            <p>Check Jenkins console for details: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                        </div>
                    </body>
                    </html>
                """

                emailext (
                    subject: "${jobName} - Build #${buildNumber} - ${pipelineStatus}",
                    body: body,
                    to: "bachtalapro@gmail.com",
                    mimeType: 'text/html'
                )
            }
        }
    }
}
