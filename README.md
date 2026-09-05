# Laboratorio Completo: Git Workshop en EC2 con Terraform

**Autor:** José Antonio Villarroel Cires  
**Fecha:** Septiembre 2026  
**Repositorio:** [AUY1102-git-workshop](https://github.com/Joseantonio777/AUY1102-git-workshop)  
**Basado en:** [v-teacher/AUY1102](https://github.com/v-teacher/AUY1102/blob/main/content/git.md)

---

## Índice

1. [Objetivo](#1-objetivo)
2. [Arquitectura](#2-arquitectura)
3. [Paso 1: Instalar Terraform en CloudShell](#3-paso-1-instalar-terraform-en-cloudshell)
4. [Paso 2: Crear la EC2 con Terraform](#4-paso-2-crear-la-ec2-con-terraform)
5. [Paso 3: Desplegar la infraestructura](#5-paso-3-desplegar-la-infraestructura)
6. [Paso 4: Conectarse a la EC2 via SSM](#6-paso-4-conectarse-a-la-ec2-via-ssm)
7. [Paso 5: Crear y ejecutar el script del workshop](#7-paso-5-crear-y-ejecutar-el-script-del-workshop)
8. [Paso 6: Verificar resultados](#8-paso-6-verificar-resultados)
9. [Paso 7: Push a GitHub](#9-paso-7-push-a-github)
10. [Paso 8: Subir documentación al repo](#10-paso-8-subir-documentacion-al-repo)
11. [Paso 9: Limpieza](#11-paso-9-limpieza)
12. [Script completo: git-workshop.sh](#12-script-completo-git-workshopsh)
13. [Problemas encontrados y soluciones](#13-problemas-encontrados-y-soluciones)
14. [Comandos Git aprendidos](#14-comandos-git-aprendidos)

---

## 1. Objetivo

Desplegar una instancia EC2 en AWS usando Terraform desde CloudShell, conectarse via SSM (Session Manager), y ejecutar un workshop completo de Git que simula la colaboración entre dos escritores (Alice y Bob) en un libro llamado "Tim and the Waves".

---

## 2. Arquitectura

```
┌──────────────────────────────────────────────────────┐
│                    AWS Cloud                         │
│                                                      │
│  ┌─────────────┐         ┌─────────────────────┐    │
│  │  CloudShell  │──SSM──▶│  EC2 (t3.medium)     │    │
│  │  (Terraform) │         │  Amazon Linux 2023   │    │
│  └─────────────┘         │  20 GB gp3           │    │
│                           │  LabInstanceProfile   │    │
│                           │                       │    │
│                           │  ~/git-workshop/      │    │
│                           │    ├── alice/book/    │    │
│                           │    ├── bob/book/      │    │
│                           │    └── central.git/   │    │
│                           └─────────────────────┘    │
│                                    │                  │
└────────────────────────────────────│──────────────────┘
                                     │ git push
                                     ▼
                            ┌─────────────────┐
                            │  GitHub          │
                            │  Joseantonio777/ │
                            │  AUY1102-git-    │
                            │  workshop        │
                            └─────────────────┘
```

---

## 3. Paso 1: Instalar Terraform en CloudShell

AWS CloudShell no trae Terraform preinstalado. El método `yum` con el repo de HashiCorp no funcionó, así que se instaló el binario directo:

```bash
curl -O https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform -version
```

**Salida esperada:**
```
Terraform v1.9.8
on linux_amd64
```

---

## 4. Paso 2: Crear la EC2 con Terraform

Se creó un directorio de trabajo y el archivo de infraestructura:

```bash
mkdir ~/ec2-lab && cd ~/ec2-lab
```

### Archivo main.tf

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "server" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.medium"
  iam_instance_profile = "LabInstanceProfile"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "ec2-lab"
  }
}

output "instance_id" {
  value = aws_instance.server.id
}

output "public_ip" {
  value = aws_instance.server.public_ip
}
```

### Notas sobre el main.tf

- **LabInstanceProfile**: perfil IAM preexistente en AWS Academy. Incluye permisos de SSM para conectarse sin key pair ni security group. Se verificó con:
  ```bash
  aws iam list-instance-profiles --query "InstanceProfiles[*].[InstanceProfileName,Roles[0].RoleName]" --output table
  ```
  Resultado:
  ```
  +----------------------+-----------------------+
  |  EMR_EC2_DefaultRole |  EMR_EC2_DefaultRole  |
  |  LabInstanceProfile  |  LabRole              |
  +----------------------+-----------------------+
  ```

- **t3.medium**: 2 vCPUs, 4 GB RAM — suficiente para el workshop.
- **gp3 20 GB**: disco SSD de propósito general.
- **No se pudo crear un rol IAM propio** porque el entorno de AWS Academy restringe `iam:CreateRole`.

---

## 5. Paso 3: Desplegar la infraestructura

```bash
terraform init
```
Descarga el provider de AWS.

```bash
terraform apply -auto-approve
```
Crea la instancia EC2.

**Salida esperada:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
instance_id = "i-0e6f9657286f418a7"
public_ip = "18.212.89.234"
```

---

## 6. Paso 4: Conectarse a la EC2 via SSM

### Primer intento (falló)

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```
Error: `TargetNotConnected` — la instancia no tenía el IAM profile asociado porque el `sed` que intentaba inyectar la línea en main.tf no funcionó correctamente.

### Solución

Se reescribió el `main.tf` completo con el `iam_instance_profile = "LabInstanceProfile"` incluido y se forzó la recreación:

```bash
terraform apply -replace="aws_instance.server" -auto-approve
```

### Verificar que SSM detecta la instancia

```bash
aws ssm describe-instance-information \
  --query "InstanceInformationList[?InstanceId=='$(terraform output -raw instance_id)'].PingStatus" \
  --output text
```

Cuando responde `Online` (tarda ~2 minutos), conectarse:

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```

**Indicador de que estás dentro:** el prompt cambia a `sh-5.2$`

---

## 7. Paso 5: Crear y ejecutar el script del workshop

Dentro de la EC2 (por SSM), se creó el script con todo el workshop corregido para Amazon Linux 2023:

```bash
cat > ~/git-workshop.sh << 'SCRIPT'
#!/bin/bash
set -e
WORKDIR=~/git-workshop
rm -rf $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

# ============================================================
# DEPENDENCIAS
# git: control de versiones
# ed: editor de texto en linea, edita archivos programaticamente
# delta: herramienta visual de diff, mejora el diff de git
# ============================================================
sudo dnf update -y
sudo dnf install git ed -y

# Delta: binario directo porque Amazon Linux no soporta .deb
if ! command -v delta &> /dev/null; then
  curl -LO https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
  tar -xvf delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
  sudo mv delta-0.18.2-x86_64-unknown-linux-musl/delta /usr/local/bin/
  rm -rf delta-0.18.2-x86_64-unknown-linux-musl*
fi

# ============================================================
# ALICE: INICIALIZACION DEL REPOSITORIO
# Crea workspace, escribe capitulo 1, descubre que copiar
# archivos no escala y decide usar git.
# ============================================================
mkdir -p alice/book && cd alice/book

cat << EOF > chapter-01.md
## Tim and the waves

Being a young boy, Tim had always been fascinated with the ocean. He would spend hours at the beach, watching the waves crash against the shore, imagining all the creatures that lived beneath the surface. One day, he decided to go for a swim, but before he knew it, he was caught in a strong current and dragged out to sea.

As the waves tossed him around, Tim struggled to stay afloat. Just when he thought he couldn't hold on any longer, a strong hand grabbed his wrist and pulled him to safety. It was a kind stranger who had noticed him struggling from the shore.

From that day forward, Tim's love for the ocean only grew stronger. But he never forgot the lesson he had learned - that sometimes, even the strongest of us need help from others to make it through the rough waters of life.
EOF

# Mala practica: copiar archivo para hacer cambios
cp chapter-01.md chapter-01v2.md
ed chapter-01v2.md << EOF
2i

Tim is a lean and athletic young man with short brown hair and piercing blue eyes. He has a strong jawline and a sun-kissed complexion from spending so much time at the beach. His body is toned and muscular from his active lifestyle, and he exudes a sense of energy and enthusiasm for life.
.
w
q
EOF

# Alice se da cuenta que copiar no escala -> usa git
rm chapter-01v2.md

# git init: crea la base de datos de git en .git/
git config --global init.defaultBranch main
git init

# Identidad (obligatorio para hacer commits)
git config user.name Alice
git config user.email alice@example.com

# ============================================================
# ALICE: PRIMEROS COMMITS
# git add: mueve archivos al staging area
# git commit: guarda snapshot permanente en el historial
# ============================================================
git add chapter-01.md
git commit -m "Initial draft of the first chapter"

# Agrega descripcion de Tim con confianza (git guarda el historial)
ed chapter-01.md << EOF
2i

Tim is a lean and athletic young man with short brown hair and piercing blue eyes. He has a strong jawline and a sun-kissed complexion from spending so much time at the beach. His body is toned and muscular from his active lifestyle, and he exudes a sense of energy and enthusiasm for life.
.
w
q
EOF

git add chapter-01.md
git commit -m "Added description of Tim"
PREV_REVISION=$(git rev-parse HEAD~1)

# ============================================================
# ALICE: CONFIGURACION DE DELTA
# Mejora la visualizacion de diffs con colores y side-by-side
# ============================================================
git config core.pager "delta"
git config interactive.diffFilter "delta --color-only"
git config delta.navigate true
git config delta.light false
git config delta.side-by-side true
git config delta.line-numbers true
git config merge.conflictstyle diff3
git config diff.colorMoved default

# ============================================================
# ALICE: DETACHED HEAD
# git checkout <hash>: viaja en el tiempo a un commit especifico
# HEAD queda suelto (detached), no esta en ningun branch
# git switch -: vuelve al branch donde estabas
# ============================================================
git checkout $PREV_REVISION 2>/dev/null || true
git switch - 2>/dev/null

# ============================================================
# ALICE: BRANCHING BASICO
# git checkout -b: crea branch nuevo y se mueve a el
# Permite trabajar en paralelo sin afectar main
# ============================================================
git checkout -b vocabulary-chapter-01

# Reemplaza segunda aparicion de "beach" por "soar"
# sed -z trata todo el archivo como una sola linea
sed -z -i 's/beach/soar/2' chapter-01.md
git add chapter-01.md
git commit -m "Replacing repetitive words"

# Vuelve a main para hacer cambio independiente
git checkout main
sed -i 's/a kind stranger/the likehouse keeper/' chapter-01.md
git add chapter-01.md
git commit -m "Introducing the lighthouse keeper"

# ============================================================
# MERGE SIN CONFLICTO
# Cambios en lineas diferentes -> git los combina automaticamente
# Usa la estrategia ORT (Ostensibly Recursive's Twin)
# ============================================================
git merge vocabulary-chapter-01 -m "Merged vocabulary"

# ============================================================
# MERGE CON CONFLICTO
# Ambos branches modifican la misma zona del archivo
# Git no puede decidir cual usar -> marca el conflicto con:
#   <<<<<<< HEAD (version actual)
#   ======= (separador)
#   >>>>>>> branch (version del otro branch)
# ============================================================

# Cambio en main
sed -i 's/afloat/afloat, fighting the waves/' chapter-01.md
git add chapter-01.md
git commit -m "Enhanced paragraph"

# Cambio en vocabulary branch
git checkout vocabulary-chapter-01
sed -i 's/struggling/floundering/' chapter-01.md
git add chapter-01.md
git commit -m "Replaced struggling"

# Merge: git detecta el conflicto
git checkout main
git merge vocabulary-chapter-01 -m "Merged vocabulary" || true

# Resolucion manual: eliminar marcadores y escribir version final
L0=$(grep -n "<<<<<<<" chapter-01.md | cut -f1 -d:)
LF=$(grep -n ">>>>>>>" chapter-01.md | cut -f1 -d:)

ed chapter-01.md << EOF
${L0},${LF}d
7i
As the waves tossed him around, Tim struggled to stay afloat, fighting the waves. Just when he thought he couldn't hold on any longer, a strong hand grabbed his wrist and pulled him to safety. It was the lighthouse keeper who had noticed him floundering from the shore.
.
w
q
EOF

git add chapter-01.md
git commit -m "Solved conflict, merged keeper and floundering."

# ============================================================
# TAGS
# git tag -a: crea tag anotado (con mensaje y metadata)
# Marcan versiones importantes (releases)
# ============================================================
git branch -d vocabulary-chapter-01
git tag -a v1 -m "First chapter is ready to be reviewed!"

cd ../../

# ============================================================
# BOB: CLONE
# git clone: copia completa del repositorio (historial incluido)
# Mantiene un remote llamado origin apuntando al original
# ============================================================
mkdir -p bob && cd bob
git clone ../alice/book
cd book
git config user.name Bob
git config user.email bob@example.com

# ============================================================
# BOB: PUSH
# Escribe capitulo 2 e intenta sincronizar con Alice
# Push directo a repo con working tree falla por seguridad
# Solucion: crear branch y hacer push de ese branch
# ============================================================
cat << EOF > chapter-02.md
Tim couldn't believe his luck. The stranger had saved his life, and he was filled with gratitude. "Thank you so much," he said, still panting from the ordeal. "I thought I was going to drown out there."

The lighthouse keeper smiled kindly at him. "You're welcome," he said. "But you should be more careful. The ocean can be dangerous, especially when there's a strong current like today."

Tim nodded, his heart still racing. He realized that he had underestimated the power of the ocean, and he felt humbled by the experience. From that moment on, he made a vow to always respect the sea and to never take its power for granted.

As they made their way back to the shore, the lighthouse keeper introduced himself as John, and they struck up a conversation. Tim learned that John had spent his life guiding ships safely through the treacherous waters of the coast. He was now enjoying his retirement in the nearby town, where he relished fishing and spending time with his grandchildren.

As they said their goodbyes, John turned to Tim with a twinkle in his eye. "Have you ever heard of the mermaids?" he asked, his voice filled with mystery
EOF

git add chapter-02.md
git commit -m "Added chapter 2."
git push origin main 2>/dev/null || true
git checkout -b wip-chapter-02
git push origin wip-chapter-02

cd ../../

# ============================================================
# ALICE: MERGE DEL TRABAJO DE BOB
# ============================================================
cd alice/book
git merge wip-chapter-02
git branch -d wip-chapter-02
cd ../../

# ============================================================
# REPOSITORIO CENTRALIZADO (BARE)
# git init --bare: repo sin working tree, solo base de datos
# Ideal como punto central de sincronizacion
# Equivalente local de un repo en GitHub
# ============================================================
mkdir central.git && cd central.git
git init --bare --shared
cd ..

cd alice/book
git remote add origin ../../central.git/
git push origin main
git push origin v1

# ============================================================
# ALICE: NUEVO CAPITULO
# Escribe capitulo 3 y lo pushea al central
# ============================================================
cat << EOF > chapter-03.md
Tim woke up with a start, his heart racing and his body drenched in sweat; it took him a few moments to realize that he had been dreaming about the mermaids again. He had been having the same dream for weeks now - the mermaids would appear out of nowhere, their beautiful faces twisted into a sinister snarl as they dragged him under the water.

He knew it was silly to be afraid of something that didn't exist, but he couldn't shake the feeling that there was some truth to his dreams. The sea was full of mysteries and he had heard stories of sailors who had encountered strange creatures on their voyages. Perhaps there was more to his dreams than just his imagination.

As he lay in bed, trying to calm his racing thoughts, Tim made a decision. He would set out to learn as much as he could about the sea and the creatures that dwelled within it. If there was any truth to his dreams, he wanted to be prepared. And he knew where to start his investigation.
EOF

git add chapter-03.md
git commit -m "New chapter"
git push origin main
cd ../..

# ============================================================
# BOB: PULL
# git fetch: descarga datos del remote sin modificar working tree
# git pull: hace fetch + merge en un solo paso
# ============================================================
cd bob/book
git checkout main
git remote rename origin alice
git remote add origin ../../central.git/
git fetch origin main
git pull origin main
cd ../..

echo ""
echo "============================================"
echo "  Workshop Git finalizado exitosamente!"
echo "============================================"
echo "  alice/book/   - Repo de Alice (3 capitulos, tag v1)"
echo "  bob/book/     - Repo de Bob (3 capitulos post-pull)"
echo "  central.git/  - Repo bare centralizado"
SCRIPT
```

### Ejecución

```bash
chmod +x ~/git-workshop.sh
bash ~/git-workshop.sh
```

**Salida final esperada:**
```
============================================
  Workshop Git finalizado exitosamente!
============================================
  alice/book/   - Repo de Alice (3 capitulos, tag v1)
  bob/book/     - Repo de Bob (3 capitulos post-pull)
  central.git/  - Repo bare centralizado
```

---

## 8. Paso 6: Verificar resultados

```bash
cd ~/git-workshop

# Los 3 repos existen
ls -d alice/book bob/book central.git

# Ambos tienen 3 capitulos
ls alice/book/chapter-*.md
ls bob/book/chapter-*.md

# Tag v1 existe
cd alice/book && git tag && cd ../..

# Historial completo (~10 commits)
cd alice/book && git log --graph --oneline && cd ../..
```

**Historial esperado:**
```
f59aca5 New chapter
1a677e7 Added chapter 2.
7b0ea49 Solved conflict, merged keeper and floundering.
1749394 Enhanced paragraph
e61796a Replaced struggling
8e3a5b6 Merged vocabulary
7512ef0 Replacing repetitive words
5657aa9 Introducing the lighthouse keeper
b546f81 Added description of Tim
67f8d39 Initial draft of the first chapter
```

---

## 9. Paso 7: Push a GitHub

### 9.1 Crear repo vacío en GitHub

Se creó el repo `AUY1102-git-workshop` en GitHub sin README, sin .gitignore, sin licencia.

### 9.2 Configurar remote y push

```bash
cd ~/git-workshop/alice/book
git remote remove origin
git remote add origin https://github.com/Joseantonio777/AUY1102-git-workshop.git
git push -u origin main
git push origin v1
```

### 9.3 Autenticación

GitHub ya no acepta contraseña, se necesita un Personal Access Token:

1. Ir a https://github.com/settings/tokens
2. Generate new token (classic)
3. Marcar scope **repo**
4. Generate token
5. Copiar y usar como contraseña al hacer push

**Credenciales al push:**
```
Username: Joseantonio777
Password: (Personal Access Token)
```

---

## 10. Paso 8: Subir documentación al repo

Se copió el script y la guía al repo y se subieron a GitHub:

```bash
cd ~/git-workshop/alice/book
cp ~/git-workshop.sh .
# (crear git-workshop-guia.md con la documentacion)
git add git-workshop.sh git-workshop-guia.md
git commit -m "Agregado script y guia del workshop"
git push origin main
```

---

## 11. Paso 9: Limpieza

Desde CloudShell (no desde la EC2):

```bash
cd ~/ec2-lab
terraform destroy -auto-approve
```

Esto elimina la instancia EC2 y todos los recursos asociados.

---

## 12. Script completo: git-workshop.sh

El script completo se encuentra incluido en el Paso 5 de este documento y también en el repositorio como archivo `git-workshop.sh`.

Para ejecutarlo en una EC2 nueva con Amazon Linux 2023:

```bash
bash ~/git-workshop.sh
```

El script:
- Instala git, ed y delta
- Ejecuta todo el workshop de forma automática
- Crea la estructura alice/book, bob/book y central.git
- Cada sección está comentada explicando qué hace y por qué

---

## 13. Problemas encontrados y soluciones

| # | Problema | Causa | Solución |
|---|----------|-------|----------|
| 1 | `terraform: command not found` | CloudShell no trae Terraform | Instalar binario directo con curl |
| 2 | `Inconsistent dependency lock file` | No se ejecutó `terraform init` | Ejecutar `terraform init` antes de plan |
| 3 | `TargetNotConnected` en SSM | EC2 no tenía IAM profile asociado | Reescribir main.tf con `iam_instance_profile` y recrear instancia |
| 4 | `AccessDenied: iam:CreateRole` | AWS Academy restringe creación de roles | Usar `LabInstanceProfile` preexistente |
| 5 | `sed` no inyectó línea en main.tf | Sintaxis de sed no funcionó como esperado | Reescribir main.tf completo con `cat >` |
| 6 | Delta: `dpkg` no existe en Amazon Linux | El workshop original es para Debian/Ubuntu | Instalar delta desde binario .tar.gz |
| 7 | `wget` no disponible | No viene preinstalado en Amazon Linux 2023 | Usar `curl -LO` |
| 8 | Bob: `../../central/` no existe | Typo en el workshop original | Corregir a `../../central.git/` |

---

## 14. Comandos Git aprendidos

| Comando | Descripción |
|---------|-------------|
| `git init` | Inicializa un repositorio, crea directorio .git/ |
| `git config user.name` | Configura nombre del autor para commits |
| `git config user.email` | Configura email del autor para commits |
| `git add <archivo>` | Mueve archivo al staging area (listo para commit) |
| `git commit -m "msg"` | Guarda snapshot permanente con mensaje descriptivo |
| `git status` | Muestra estado actual: archivos modificados, staged, untracked |
| `git log` | Muestra historial de commits |
| `git log --graph --oneline` | Historial compacto con gráfico de branches |
| `git diff` | Muestra diferencias entre working tree y staging |
| `git show <ref>:<archivo>` | Muestra contenido de un archivo en un commit específico |
| `git rev-parse HEAD` | Obtiene el hash SHA-1 del commit actual |
| `git rev-parse HEAD~1` | Obtiene el hash del commit anterior |
| `git checkout <hash>` | Viaja en el tiempo a un commit (detached HEAD) |
| `git switch -` | Vuelve al branch donde estabas |
| `git checkout -b <branch>` | Crea branch nuevo y se mueve a él |
| `git branch` | Lista todos los branches locales |
| `git branch -d <branch>` | Elimina un branch ya mergeado |
| `git merge <branch>` | Combina un branch con el actual |
| `git tag v1` | Crea tag ligero (solo puntero) |
| `git tag -a v1 -m "msg"` | Crea tag anotado (con metadata) |
| `git tag -d v1` | Elimina un tag |
| `git clone <repo>` | Copia completa de un repositorio |
| `git remote` | Lista repositorios remotos configurados |
| `git remote add origin <url>` | Agrega un remote |
| `git remote remove origin` | Elimina un remote |
| `git remote rename <old> <new>` | Renombra un remote |
| `git push origin <branch>` | Sube branch a un remote |
| `git push origin <tag>` | Sube tag a un remote |
| `git fetch origin <branch>` | Descarga datos sin modificar working tree |
| `git pull origin <branch>` | Fetch + merge en un solo paso |
| `git diff FETCH_HEAD` | Compara working tree con lo descargado por fetch |
| `git init --bare --shared` | Crea repo sin working tree (para servidor) |
