#Requires -Version 7.1

<#
.SYNOPSIS
Exécute une des trois tâches prévues dans la consigne du défi technique N°3
.DESCRIPTION
L'option 1 sert à lister les builds en cours d'exécution et les jobs associés sur un serveur Jenkins spécifié
L'option 2 sert à stopper les builds en cours d'exécution depuis plus d'une heure sur un serveur Jenkins spécifié
L'option 3 lance le build d'un job définit à un temps donné
.NOTES
Les paramètres obligatoires sont :
    - Option
    - User
    - Token
    - JenkinsURI

Les paramètres factultatifs (cependant obligatoires pour l'option 3) sont :
    - JenkinsJob
    - JenkinsJobTime
.EXAMPLE
PS> Challenge_3.ps1 -Option 1 -User "alegrand" -Token "abcd1234" -JenkinsURI "https://www.myjenkinsserver.com"
PS> Challenge_3.ps1 -Option 3 -User "alegrand" -Token "abcd1234" -JenkinsURI "https://www.myjenkinsserver.com" -JenkinsJob "myJenkinsJob" -JenkinsJobTime "10:00"
#>


PARAM (
    [PARAMETER (HelpMessage = "Option qui va définir l'action du script. Choix possibles : '1', '2' ou '3'", Mandatory = $true)][ValidateNotNullOrEmpty()] $option,
    [PARAMETER (HelpMessage = "Utilisateur Jenkins avec lequel la requête web va être exécutée", Mandatory = $true)][ValidateNotNullOrEmpty()] [string]$user,
    [PARAMETER (HelpMessage = "Token associé à l'utilisateur Jenkins", Mandatory = $true)][ValidateNotNullOrEmpty()] [string]$token,
    [PARAMETER (HelpMessage = "URI du serveur web Jenkins", Mandatory = $true)][ValidateNotNullOrEmpty()] [string]$jenkinsURI,
    [PARAMETER (HelpMessage = "Nom du job Jenkins à démarrer", Mandatory = $false)] [string]$jenkinsJob,
    [PARAMETER (HelpMessage = "Heure à laquelle le job Jenkins doit démarrer", Mandatory = $false)] [string]$jenkinsJobTime
)


# Ce bloc commenté peut être utilisé à des fins de test
# Il faudra dé-commenter ce bloc, et commenter le bloc de paramètres ci-dessus
<# Clear-Host
$option = "1" # 1 ou 2 ou 3
$user = "alegrand" # Nom d'utilisateur Jenkins
$token = "abcd1234" # Token associé au nom d'utilisateur Jenkins ci-dessus
$jenkinsURI = "http://localhost:8080" # URI du serveur web Jenkins (et port associé si besoin, par ex. : https://www.myjenkinsserver.com:8080)
#############################################
# Les paramètres suivants sont factultatifs
$jenkinsJob = "simple-java-maven-app" # Obligatoire pour l'option 3
$jenkinsJobTime = "19:00" # Obligatoire pour l'option 3 #>



##################################################################################################################
# Début du bloc de fonctions personnalisées
##################################################################################################################
function ValidateUri ([string]$Uri = ($paramMissing = $true)) {
    <#
    .SYNOPSIS
        Valide le fait que l'URI soumise respecte le bon format
    .DESCRIPTION
        Cette fonction utilise une expression régulière pour valider que l'URI fournie en entrée respecte le bon format
        L'URI attendue doit commencer par "http://" ou "https://"
    .EXAMPLE
        ValidateUri -Uri https://www.impots.gouv.fr
        ValidateUri -Uri http://google.fr
    #>

    ##################################################################################################################
    # Début des vérifications préliminaires
    ##################################################################################################################
    Write-Verbose "[ValidateUri] Entrée dans la fonction ValidateUri"
    Write-Verbose "[ValidateUri] Début des vérifications préliminaires"

    # S'il manque un paramètre
    if ($local:paramMissing) {
        Write-Verbose "[ValidateUri] Sortie de la fonction ValidateUri - il manque le paramètre -Uri !"

        # Arrêt du script en renvoyant une erreur explicative
        throw "[ValidateUri] UTILISATION : ValidateUri -Uri <Uri>"
    }

    Write-Verbose "[ValidateUri] Fin des vérifications préliminaires - SUCCÈS"
    ##################################################################################################################
    # Fin des vérifications préliminaires
    ##################################################################################################################



    ##################################################################################################################
    ##################################### Début du code principal de la fonction #####################################
    ##################################################################################################################
    
    # La chaîne de caractère ne commence pas par "http://" ou "https://"
    if ((($Uri -match "^http://*") -eq $false) -and (($Uri -match "^https://*") -eq $false)) {
        # Arrêt du script en renvoyant une erreur explicative
        throw "[ValidateUri] ERREUR : L'URI doit commencer par 'http://' ou 'https://'"
    }

    # Vérification terminée
    Write-Verbose "[ValidateUri] Sortie de la fonction ValidateUri, l'URI a un format conforme"
}


function JenkinsRequest {
    <#
    .SYNOPSIS
        Permet de récupérer le résultat d'une requête Web auprès du serveur Jenkins
    .DESCRIPTION
        Récupère le crumb et authentifie l'utilisateur auprès du serveur Jenkins
        Selon la méthode utilisée, récupère le contenu d'une page Web ou envoie une requête d'exécution via l'API REST
    .EXAMPLE
        JenkinsRequest -Uri "https://www.myjenkinsserver.com/api/json?tree=jobs[name,url,builds[building,timestamp,number,result,duration]]" -Method "Get"
    #>

    PARAM(
        [PARAMETER (HelpMessage = "URI sur laquelle on va contacter le serveur Jenkins", Mandatory = $true)][ValidateNotNullOrEmpty()][Alias("Uri")] [string]$uriFormat,
        [PARAMETER (HelpMessage = "Méthode 'Get' ou 'Post'", Mandatory = $true)][ValidateNotNullOrEmpty()][Alias("Method")] [string]$urlMethod
    )

    ##################################################################################################################
    # Début des vérifications préliminaires
    ##################################################################################################################
    Write-Verbose "[JenkinsRequest] Entrée dans la fonction JenkinsRequest"
    Write-Verbose "[JenkinsRequest] Début des vérifications préliminaires"

    # Vérifie que l'URI fournie respecte le bon format, et que le token soit correct
    ValidateUri -Uri $uriFormat

    # Vérifie que la valeur du paramètre -Method est une de celles attendues
    if (($urlMethod -ne "Get") -and ($urlMethod -ne "Post")) {
        Write-Verbose "[JenkinsRequest] Sortie de la fonction JenkinsRequest, valeur reçue dans le paramètre -Method incorrecte"
        
        # Arrêt du script en renvoyant une erreur explicative
        throw "[JenkinsRequest] ERREUR : Le paramètre -Method ne supporte pas la valeur '$urlMethod' (valeurs supportées : 'Get' et 'Post')"
    }

    Write-Verbose "[JenkinsRequest] Fin des vérifications préliminaires - SUCCÈS"
    ##################################################################################################################
    # Fin des vérifications préliminaires
    ##################################################################################################################



    ##################################################################################################################
    ##################################### Début du code principal de la fonction #####################################
    ##################################################################################################################
    
    # Le header est le nom d'utilisateur et le token concaténés ensemble
    $pair = "$($user):$($token)"
    # Le credential combiné est converti en Base64
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    # On passe cela dans le header "Authorization"
    $Headers = @{
        Authorization = $basicAuthValue
    }

    # Création d'une requête Web pour récupérer le crumb. Ce sera récupéré au format JSON
    $jenkinsURI_Crumb = $jenkinsURI + "/crumbIssuer/api/json"
    $jenkinsJSON_Crumb = Invoke-WebRequest -Uri $jenkinsURI_Crumb -Headers $Headers

    $HTTP_Status = [int]$jenkinsJSON_Crumb.StatusCode
    Write-Verbose "Le serveur web Jenkins renvoie le code HTTP $HTTP_Status"
    
    # On va rentrer dans cette condition si le serveur ne répond pas (code HTTP = 0)
    if ($HTTP_Status -eq 0) {
        # Arrêt du script en renvoyant une erreur explicative
        throw "ERREUR : Le serveur web Jenkins ($jenkinsURI) ne répond pas. Vérifier l'URI ou le couple nom d'utilisateur / token"
    }
    # On va rentrer dans cette condition si le serveur ne répond pas comme attendu (code HTTP =!= 0 et =!= 200)
    elseif ($HTTP_Status -ne 200) {
        # Arrêt du script en renvoyant une erreur explicative
        throw "ERREUR : Le serveur web Jenkins ne renvoie pas le code HTTP 200 attendu (code HTTP reçu = $HTTP_Status)"
    }
    # Si aucune des conditions ci-dessus n'est respectée, cela signifie que le serveur est joignable et disponible

    # Parse du JSON pour récupérer la valeur qu'il nous faut
    $parsedJson_Jenkins_Crumb = $jenkinsJSON_Crumb | ConvertFrom-Json
    # [Verbose] Affichage du crumb Jenkins
    Write-Verbose "Le crumb Jenkins est $($parsedJson_Jenkins_Crumb.crumb)"
    # Extraction du crumb et assignation au header "Jenkins-Crumb"
    $BuildHeaders = @{
        "Jenkins-Crumb" = $parsedJson_Jenkins_Crumb.crumb
        Authorization   = $basicAuthValue
    }

    # Création d'une requête Web pour récupérer les données concernant les builds Jenkins
    $requestResult = Invoke-WebRequest -Uri $uriFormat -Headers $BuildHeaders -Method $urlMethod
    
    # [Verbose] Serveur Jenkins contacté
    Write-Verbose "[JenkinsRequest] Sortie de la fonction JenkinsRequest, le contenu de la page Web a bien été récupéré"

    return $requestResult
}
##################################################################################################################
# Fin du bloc de fonctions personnalisées
##################################################################################################################



##################################################################################################################
# Début des vérifications préliminaires
##################################################################################################################

# Début des vérifications préliminaires du code principal
Write-Verbose "[CodePrincipal] Entrée dans les vérifications préliminaires"

# Pour savoir ce qu'effectue cette option, se référer au code ci-dessous, et/ou à la documentation associée à ce script
if ($option -eq 1) {
    Write-Output "Option choisie : 1"
    Write-Verbose "L'option 1 sert à lister les builds en cours d'exécution et les jobs associés sur un serveur Jenkins spécifié"
}
# Pour savoir ce qu'effectue cette option, se référer au code ci-dessous, et/ou à la documentation associée à ce script
elseif ($option -eq 2) {
    Write-Output "Option choisie : 2"
    Write-Verbose "L'option 2 sert à stopper les builds en cours d'exécution depuis plus d'une heure sur un serveur Jenkins spécifié"
}
# Pour savoir ce qu'effectue cette option, se référer au code ci-dessous, et/ou à la documentation associée à ce script
elseif ($option -eq 3) {
    Write-Output "Option choisie : 3"
    Write-Verbose "L'option 3 lance le build d'un job définit à un temps donné"
}
# On rentre dans cette condition si l'option donnée en paramètre du script n'existe pas
else {
    # Arrêt du script en renvoyant une erreur explicative
    throw "UTILISATION : L'option fournie ($option) n'est pas supportée. Valeurs possibles : '1', '2' ou '3'"
}


# Vérification complémentaire si l'option choisie est la 3, afin de vérifier que le nom du job Jenkins fournit existe
if ($option -eq "3") {
    if ([string]::IsNullOrEmpty($jenkinsJob) -eq $true) {
        throw "ERREUR : Le paramètre -JenkinsJob n'est pas renseigné, et est nécessaire pour l'option 3"
    }

    if ([string]::IsNullOrEmpty($jenkinsJobTime) -eq $true) {
        throw "ERREUR : Le paramètre -JenkinsJobTime n'est pas renseigné, et est nécessaire pour l'option 3"
    }
    
    # Parse en JSON
    $data = JenkinsRequest -Uri "$jenkinsURI/api/json" -Method "Get" | ConvertFrom-Json
    # Cette variable, si elle reste à $false, signifie que le nom du job Jenkins fournit n'existe pas
    $jobNameFound = $false

    # On va vérifier chaque élément "name" de la réponse parsée en JSON
    foreach ($jobName in $data.jobs.name) {
        # On va rentrer dans cette condition si le nom du job Jenkins fournit existe
        if ($jobName -eq $jenkinsJob) {
            Write-Verbose "[CodePrincipal] Le job Jenkins $jenkinsJob fournit en paramètre existe sur le serveur"

            # Changement de la valeur de la variable à $true, ce qui signifie que le nom du job Jenkins existe
            $jobNameFound = $true
            # Sortie de la boucle. Ce n'est pas la peine de terminer la vérification du reste des éléments de la boucle
            break
        }
    }

    # On rentre dans cette condition si le nom du job Jenkins fournit n'existe pas
    if ($jobNameFound -eq $false) {
        # Arrêt du script en renvoyant une erreur explicative
        throw "ERREUR : Le nom du job Jenkins fournit ($jenkinsJob) n'existe pas sur le serveur"
    }

    # On rentre dans cette condition si l'heure fournie en paramètre est tout sauf une heure correcte
    if (($jenkinsJobTime -match "^([01][0-9]|2[0-3]):([0-5][0-9])$") -eq $false) {
        # Arrêt du script en renvoyant une erreur explicative
        throw "ERREUR : L'heure d'exécution du job Jenkins fournie en paramètre ($jenkinsJobTime) n'est pas du format 'HH:mm' et/ou est invalide"
    }
}

# Fin des vérifications préliminaires du code principal
Write-Verbose "[CodePrincipal] Entrée dans les vérifications préliminaires"
##################################################################################################################
# Fin des vérifications préliminaires
##################################################################################################################



###################################################################################################################
######################################## Début du code principal du script ########################################
###################################################################################################################

# Début du code principal
Write-Verbose "[CodePrincipal] Entrée dans le code principal"

# Les options 1 et 2 traitent des données concernant des builds en cours. Ils vont partager une partie du même code
if (($option -eq "1") -or ($option -eq "2")) {
    # Parse du JSON pour récupérer les valeurs qu'il nous faut
    $data = JenkinsRequest -Uri "$jenkinsURI/api/json?tree=jobs[name,url,builds[building,timestamp,number,result,duration]]" -Method "Get" | ConvertFrom-Json

    # Chaque job Jenkins sera parcouru
    foreach ($job in $data) {
        # Récupération du nom du job
        $job_name = $data.jobs.name

        # Chaque build d'un job Jenkins sera parcouru. Les infos 'building', 'number' et 'timestamp' sont récupérées
        foreach ($build in ($data.jobs.builds | Select-Object building, number, timestamp)) {
            # On rentre dans la condition si un build est en cours d'exécution
            if ($build.building -eq $true) {
                # On rentre dans la condition si on veut simplement lister le(s) job(s) en cours d'exécution et le N° de build associé
                if ($option -eq "1") {
                    # On liste le(s) job(s) en cours d'exécution et le N° de build associé
                    Write-Output "[Job $($job_name)] Build N°$($build.number) en cours d'exécution"
                }
                # On rentre dans la condition si on veut stopper les builds en cours d'exécution depuis plus d'une heure
                elseif ($option -eq "2") {
                    # Récupération du temps du lancement du build, puis comparaison avec le temps actuel
                    $timeJenkins = Get-Date -UnixTimeSeconds ($build.timestamp / 1000)
                    $timeCurrent = Get-Date
                    $calcul = $timeCurrent - $timeJenkins
                    
                    # On rentre dans la condition si cela fait plus d'une heure que le build est en cours d'exécution
                    if ($calcul.TotalHours -gt 1) {
                        Write-Output "[Job $($job_name)] Build N°$($build.number) - En cours d'exécution depuis plus d'1h ($([math]::Round($calcul.TotalHours, 2))h) !"
                            
                        # Envoi d'une requête au serveur Jenkins pour arrêter le build
                        Write-Output "[Job $($job_name)] Build N°$($build.number) - Arrêt du build"
                        JenkinsRequest -Uri "$jenkinsURI/job/$job_name/$($build.number)/stop" -Method "Post" -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}
# L'option 3 ne partage pas le même code que les options 1 et 2
elseif ($option -eq "3") {
    # Récupération du temps souhaité du lancement du build, puis comparaison avec le temps actuel
    $timeTarget = Get-Date -Hour $jenkinsJobTime.Substring(0, 2) -Minute $jenkinsJobTime.Substring(3, 2) -Second 00
    $timeCurrent = Get-Date
    $calcul = $timeTarget - $timeCurrent

    # On rentre dans la condition si l'heure demandée est déjà passée pour ce jour
    if ($calcul.TotalSeconds -lt 0) {
        # On calcule les données nécessaires : prochain jour d'exécution, et combien de secondes on va mettre le script en pause
        $timeTarget = $timeTarget.AddDays(1)
        $calcul = $timeTarget - $timeCurrent

        Write-Output "L'heure d'exécution demandée pour exécuter le build du job $jenkinsJob est déjà passée aujourd'hui"
        Write-Output "Le lancement va avoir lieu demain, $(Get-Date -Day $timeTarget.Day -Hour $jenkinsJobTime.Substring(0, 2) -Minute $jenkinsJobTime.Substring(3, 2) -Format "dddd dd/MM, à HH:mm")"

        # On met en pause le script jusqu'au lendemain, à l'heure demandée
        Write-Verbose "[CodePrincipal] Début de la pause du script"
        Start-Sleep -Seconds $calcul.TotalSeconds
    }
    # On rentre dans la condition si l'heure demandée n'est pas encore passée ce jour
    elseif ($calcul.TotalSeconds -ge 0) {
        Write-Output "Le lancement du build du job $jenkinsJob va avoir lieu aujourd'hui, $(Get-Date -Day $timeCurrent.Day -Hour $jenkinsJobTime.Substring(0, 2) -Minute $jenkinsJobTime.Substring(3, 2) -Format "dddd dd/MM, à HH:mm")"

        # On met en pause le script jusqu'à aujourd'hui à l'heure demandée
        Write-Verbose "[CodePrincipal] Début de la pause du script"
        Start-Sleep -Seconds $calcul.TotalSeconds
    }

    # La pause est terminée
    # Envoi d'une requête au serveur Jenkins pour démarrer le job de build
    Write-Verbose "[CodePrincipal] Fin de la pause du script"
    Write-Output "[Job $($jenkinsJob)] - Démarrage du build"
    JenkinsRequest -Uri "$jenkinsURI/job/$jenkinsJob/build" -Method "Post" | Out-Null
}

# Fin du code principal
Write-Verbose "[CodePrincipal] Entrée dans le code principal"
Write-Output "Fin de l'exécution du script"
