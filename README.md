# Git Workshop en EC2 — Paso a Paso

## 1. Instalar Terraform en CloudShell

```bash
curl -O https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

## 2. Crear la EC2

```bash
mkdir ~/ec2-lab && cd ~/ec2-lab
```

Crear `main.tf`:

```bash
cat > main.tf << 'EOF'
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
EOF
```

Desplegar:

```bash
terraform init
terraform apply -auto-approve
```

## 3. Conectarse a la EC2

Esperar 2 minutos después del deploy y ejecutar desde CloudShell:

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```

Si da error `TargetNotConnected`, forzar recreación:

```bash
terraform apply -replace="aws_instance.server" -auto-approve
```

El prompt cambia a `sh-5.2$` cuando estás dentro de la EC2.

## 4. Crear el script del workshop

Dentro de la EC2, pegar todo esto:

```bash
cat > ~/git-workshop.sh << 'SCRIPT'
#!/bin/bash
set -e
WORKDIR=~/git-workshop
rm -rf $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

# --- Dependencias ---
sudo dnf update -y
sudo dnf install git ed -y

if ! command -v delta &> /dev/null; then
  curl -LO https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
  tar -xvf delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
  sudo mv delta-0.18.2-x86_64-unknown-linux-musl/delta /usr/local/bin/
  rm -rf delta-0.18.2-x86_64-unknown-linux-musl*
fi

# --- Alice: init ---
mkdir -p alice/book && cd alice/book

cat << EOF > chapter-01.md
## Tim and the waves

Being a young boy, Tim had always been fascinated with the ocean. He would spend hours at the beach, watching the waves crash against the shore, imagining all the creatures that lived beneath the surface. One day, he decided to go for a swim, but before he knew it, he was caught in a strong current and dragged out to sea.

As the waves tossed him around, Tim struggled to stay afloat. Just when he thought he couldn't hold on any longer, a strong hand grabbed his wrist and pulled him to safety. It was a kind stranger who had noticed him struggling from the shore.

From that day forward, Tim's love for the ocean only grew stronger. But he never forgot the lesson he had learned - that sometimes, even the strongest of us need help from others to make it through the rough waters of life.
EOF

cp chapter-01.md chapter-01v2.md
ed chapter-01v2.md << EOF
2i

Tim is a lean and athletic young man with short brown hair and piercing blue eyes. He has a strong jawline and a sun-kissed complexion from spending so much time at the beach. His body is toned and muscular from his active lifestyle, and he exudes a sense of energy and enthusiasm for life.
.
w
q
EOF
rm chapter-01v2.md

git config --global init.defaultBranch main
git init
git config user.name Alice
git config user.email alice@example.com

# --- Alice: commits ---
git add chapter-01.md
git commit -m "Initial draft of the first chapter"

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

# --- Alice: delta ---
git config core.pager "delta"
git config interactive.diffFilter "delta --color-only"
git config delta.navigate true
git config delta.light false
git config delta.side-by-side true
git config delta.line-numbers true
git config merge.conflictstyle diff3
git config diff.colorMoved default

# --- Alice: detached HEAD ---
git checkout $PREV_REVISION 2>/dev/null || true
git switch - 2>/dev/null

# --- Alice: branching ---
git checkout -b vocabulary-chapter-01
sed -z -i 's/beach/soar/2' chapter-01.md
git add chapter-01.md
git commit -m "Replacing repetitive words"

git checkout main
sed -i 's/a kind stranger/the likehouse keeper/' chapter-01.md
git add chapter-01.md
git commit -m "Introducing the lighthouse keeper"

# --- Alice: merge sin conflicto ---
git merge vocabulary-chapter-01 -m "Merged vocabulary"

# --- Alice: merge con conflicto ---
sed -i 's/afloat/afloat, fighting the waves/' chapter-01.md
git add chapter-01.md
git commit -m "Enhanced paragraph"

git checkout vocabulary-chapter-01
sed -i 's/struggling/floundering/' chapter-01.md
git add chapter-01.md
git commit -m "Replaced struggling"

git checkout main
git merge vocabulary-chapter-01 -m "Merged vocabulary" || true

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

# --- Alice: tags ---
git branch -d vocabulary-chapter-01
git tag -a v1 -m "First chapter is ready to be reviewed!"
cd ../../

# --- Bob: clone ---
mkdir -p bob && cd bob
git clone ../alice/book
cd book
git config user.name Bob
git config user.email bob@example.com

# --- Bob: push ---
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

# --- Alice: merge de Bob ---
cd alice/book
git merge wip-chapter-02
git branch -d wip-chapter-02
cd ../../

# --- Repo centralizado (bare) ---
mkdir central.git && cd central.git
git init --bare --shared
cd ..

cd alice/book
git remote add origin ../../central.git/
git push origin main
git push origin v1

# --- Alice: capitulo 3 ---
cat << EOF > chapter-03.md
Tim woke up with a start, his heart racing and his body drenched in sweat; it took him a few moments to realize that he had been dreaming about the mermaids again. He had been having the same dream for weeks now - the mermaids would appear out of nowhere, their beautiful faces twisted into a sinister snarl as they dragged him under the water.

He knew it was silly to be afraid of something that didn't exist, but he couldn't shake the feeling that there was some truth to his dreams. The sea was full of mysteries and he had heard stories of sailors who had encountered strange creatures on their voyages. Perhaps there was more to his dreams than just his imagination.

As he lay in bed, trying to calm his racing thoughts, Tim made a decision. He would set out to learn as much as he could about the sea and the creatures that dwelled within it. If there was any truth to his dreams, he wanted to be prepared. And he knew where to start his investigation.
EOF

git add chapter-03.md
git commit -m "New chapter"
git push origin main
cd ../..

# --- Bob: pull ---
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
echo "  alice/book/   - 3 capitulos, tag v1"
echo "  bob/book/     - 3 capitulos post-pull"
echo "  central.git/  - Repo bare centralizado"
SCRIPT
```

## 5. Ejecutar el workshop

```bash
bash ~/git-workshop.sh
```

Cuando termine muestra:

```
============================================
  Workshop Git finalizado exitosamente!
============================================
```

## 6. Verificar

```bash
cd ~/git-workshop
ls alice/book/chapter-*.md
ls bob/book/chapter-*.md
cd alice/book && git log --graph --oneline && cd ../..
```

## 7. Push a GitHub

Crear repo vacío en GitHub (sin README). Luego:

```bash
cd ~/git-workshop/alice/book
git remote remove origin
git remote add origin https://github.com/TU-USUARIO/TU-REPO.git
git push -u origin main
git push origin v1
```

Usar Personal Access Token como contraseña (GitHub > Settings > Developer settings > Tokens).

## 8. Limpieza

Desde CloudShell:

```bash
cd ~/ec2-lab
terraform destroy -auto-approve
```

---

## Qué cubre el workshop

| Paso | Qué hace |
|------|----------|
| Alice init | Crea repo, configura git, primer commit |
| Alice commits | Agrega contenido, revisa versiones anteriores |
| Alice delta | Configura diff visual con colores |
| Alice detached HEAD | Viaja en el tiempo a un commit anterior |
| Alice branching | Crea branch para vocabulario, trabaja en paralelo |
| Merge sin conflicto | Combina branches con cambios en distintas líneas |
| Merge con conflicto | Resuelve conflicto cuando ambos tocan la misma línea |
| Alice tags | Marca versión estable con tag anotado |
| Bob clone | Copia completa del repo de Alice |
| Bob push | Intenta push directo (falla), usa branch como solución |
| Repo bare | Crea repo centralizado tipo GitHub |
| Bob pull | Sincroniza desde el repo central |

## Correcciones vs workshop original

| Original | Corregido |
|----------|-----------|
| `dpkg -i delta.deb` | Binario `.tar.gz` |
| `wget` | `curl -LO` |
| `../../central/` | `../../central.git/` |
| Push sin manejar error | `|| true` |
