#Este script atualiza os usuários do Active Directory com as informações de departamento,
#empresa e gerente, além de incluí-los nos grupos GLPI correspondentes,
#assegurando que ambas as operações sejam executadas corretamente e de forma integrada.


# Importa o módulo do Active Directory
Import-Module ActiveDirectory

# Altera o Campo Empresa nas Propriedades do Usuário em Organização
$empresa = "Nome da empresa"

# Dicionário de OUs e seus respectivos departamentos
$ouDepartamentos = @{
    "OU=Nome-OU,OU=Nome-OU,DC=domínio,DC=domínio" = "Nome-OU"
}

# Dicionário de OUs e seus respectivos gerentes
$ouGerentes = @{
    "OU=Nome-OU,OU=Nome-OU,DC=domínio,DC=domínio" = "SAM-Gerente"
}

# Grupos GLPI
$grupoBase = "OU=Nome-OU,OU=Nome-OU,OU=Nome-OU,DC=domínio,DC=domínio"
$mapaOUGrupo = @{
    "Nome-Grupo"      = "OU-Grupo"
}

foreach ($ou in $ouDepartamentos.Keys) {
    $departamento = $ouDepartamentos[$ou]
    Write-Host "`nProcessando usuários da OU: $ou - Departamento: $departamento" -ForegroundColor Cyan

    # Pega os usuários da OU
    $usuarios = Get-ADUser -Filter * -SearchBase $ou -Properties SamAccountName

    # Recupera o nome curto da OU para correspondência com grupo
    $nomeOU = $departamento
    $grupoDN = $null
    if ($mapaOUGrupo.ContainsKey($nomeOU)) {
        $grupoCN = $mapaOUGrupo[$nomeOU]
        $grupoDN = "CN=$grupoCN,$grupoBase"
    }

    # Busca gerente, se houver
    $gerenteDN = $null
    if ($ouGerentes.ContainsKey($ou)) {
        $samGerente = $ouGerentes[$ou]
        $gerente = Get-ADUser -Identity $samGerente
        if ($gerente) {
            $gerenteDN = $gerente.DistinguishedName
        } else {
            Write-Warning "Gerente '$samGerente' não encontrado no AD."
        }
    }

    foreach ($usuario in $usuarios) {
        # Atualiza atributos
        Set-ADUser -Identity $usuario -Department $departamento -Company $empresa
        if ($gerenteDN) {
            Set-ADUser -Identity $usuario -Manager $gerenteDN
        }
        Write-Host "→ $($usuario.SamAccountName) atualizado com Departamento '$departamento', Empresa '$empresa'" `
            + ($(if ($gerenteDN) {", Gerente '$samGerente'" } else { "" }))

        # Adiciona ao grupo Nome-Grupo
        if ($grupoDN) {
            try {
                Add-ADGroupMember -Identity $grupoDN -Members $usuario.SamAccountName -ErrorAction Stop
                Write-Host "  [+] Adicionado: $($usuario.SamAccountName) ao grupo $grupoCN"
            } catch {
                Write-Warning "  [!] Falha ao adicionar $($usuario.SamAccountName): $_"
            }
        }
    }
}