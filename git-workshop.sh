#!/bin/bash
set -e

pause() {
  if [ -z "$YES" ]; then
    echo ""
    echo "=========================================="
    echo "  $1"
    echo "=========================================="
    read -p "Presiona ENTER para continuar..."
    echo ""
  else
    echo ">>> $1"
  fi
}

WORKDIR=~/git-workshop
rm -rf $WORKDIR
mkdir -p $WORKDIR
cd $WORKDIR

echo "=== Instalando dependencias ==="
sudo dnf update -y
sudo dnf install git ed -y
git --version

if ! command -v delta &> /dev/null; then
  curl -LO https://github.com/dandavison/delta/releases/download/0.18.2/delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
  tar -xvf delta-0.18.2-x86_64-unknown-linux-musl.tar.gz
  sudo mv delta-0.18.2-x86_64-unknown-linux-musl/delta /usr/local/bin/
  rm -rf delta-0.18.2-x86_64-unknown-linux-musl*
fi
delta --version

pause "DEPENDENCIAS INSTALADAS"

echo "=== Alice: Inicializacion del repositorio ==="
mkdir -p alice/book
cd alice/book

cat << EOF > chapter-01.md
## Tim and the waves

Being a young boy, Tim had always been fascinated with the ocean. He would spend hours at the beach, watching the waves crash against the shore, imagining all the creatures that lived beneath the surface. One day, he decided to go for a swim, but before he knew it, he was caught in a strong current and dragged out to sea.

As the waves tossed him around, Tim struggled to stay afloat. Just when he thought he couldn't hold on any longer, a strong hand grabbed his wrist and pulled him to safety. It was a kind stranger who had noticed him struggling from the shore.

From that day forward, Tim's love for the ocean only grew stronger. But he never forgot the lesson he had learned - that sometimes, even the strongest of us need help from others to make it through the rough waters of life.
EOF

ls

cp chapter-01.md chapter-01v2.md
ed chapter-01v2.md << EOF
2i

Tim is a lean and athletic young man with short brown hair and piercing blue eyes. He has a strong jawline and a sun-kissed complexion from spending so much time at the beach. His body is toned and muscular from his active lifestyle, and he exudes a sense of energy and enthusiasm for life.
.
w
q
EOF

ls
cat chapter-01v2.md
rm chapter-01v2.md

git config --global init.defaultBranch main
git init
ls -a
ls .git

git config user.name Alice
git config user.email alice@example.com
git config --list
cat .git/config

pause "CHECKPOINT — Alice: repo inicializado"

echo "=== Alice: Primeros commits ==="
git status
git add chapter-01.md
git commit -m "Initial draft of the first chapter"

git log
cat .git/HEAD
cat .git/refs/heads/main
git rev-parse --short HEAD

pause "CHECKPOINT snap01"

ed chapter-01.md << EOF
2i

Tim is a lean and athletic young man with short brown hair and piercing blue eyes. He has a strong jawline and a sun-kissed complexion from spending so much time at the beach. His body is toned and muscular from his active lifestyle, and he exudes a sense of energy and enthusiasm for life.
.
w
q
EOF

git status
git diff chapter-01.md
git add chapter-01.md
git commit -m "Added description of Tim"
git status
git log

git rev-list --all
git rev-parse HEAD
git rev-parse HEAD~1
PREV_REVISION=$(git rev-parse HEAD~1)
echo "The previous revision was $PREV_REVISION"
git show $PREV_REVISION:chapter-01.md
git show HEAD~1:chapter-01.md

pause "CHECKPOINT — Segundo commit creado"

echo "=== Alice: Configuracion de delta ==="
git config core.pager "delta"
git config interactive.diffFilter "delta --color-only"
git config delta.navigate true
git config delta.light false
git config delta.side-by-side true
git config delta.line-numbers true
git config merge.conflictstyle diff3
git config diff.colorMoved default

git show

cat .git/HEAD
cat .git/refs/heads/main
git checkout $PREV_REVISION
cat chapter-01.md
git log
cat .git/HEAD
cat .git/refs/heads/main

git switch -
git log
cat chapter-01.md
cat .git/HEAD

pause "CHECKPOINT — Delta configurado"

echo "=== Alice: Branching basico ==="
git checkout -b vocabulary-chapter-01
git status
git branch
cat .git/HEAD
cat .git/refs/heads/main
cat .git/refs/heads/vocabulary-chapter-01

cat chapter-01.md | grep beach
sed -z -i 's/beach/soar/2' chapter-01.md
cat chapter-01.md | grep -e soar -e beach
git add chapter-01.md
git commit -m "Replacing repetitive words"
git log

pause "CHECKPOINT snap02"

git checkout main
cat chapter-01.md
cat chapter-01.md | grep -e soar -e beach
git log

sed -i 's/a kind stranger/the likehouse keeper/' chapter-01.md
cat chapter-01.md
git add chapter-01.md
git commit -m "Introducing the lighthouse keeper"
git log

pause "CHECKPOINT — Lighthouse keeper en main"

echo "=== Alice: Merge sin conflictos ==="
git branch
git diff main vocabulary-chapter-01 | cat -
git merge vocabulary-chapter-01 -m "Merged vocabulary"
cat chapter-01.md
git log --oneline
git log --graph --decorate --oneline

pause "CHECKPOINT — Merge sin conflicto"

echo "=== Alice: Merge con conflicto ==="
git status
sed -i 's/afloat/afloat, fighting the waves/' chapter-01.md
git diff chapter-01.md
git add chapter-01.md
git commit -m "Enhanced paragraph"

git checkout vocabulary-chapter-01
cat chapter-01.md | grep strug
sed -i 's/struggling/floundering/' chapter-01.md
git diff chapter-01.md
git add chapter-01.md
git commit -m "Replaced struggling"

pause "CHECKPOINT snap03"

git checkout main
git merge vocabulary-chapter-01 -m "Merged vocabulary" || true
git status
git diff --name-only --diff-filter=U --relative
cat chapter-01.md

L0=$(grep -n "<<<<<<<" chapter-01.md | cut -f1 -d:)
LF=$(grep -n ">>>>>>>" chapter-01.md | cut -f1 -d:)
echo "Replacing from $L0 to $LF."

ed chapter-01.md << EOF
${L0},${LF}d
7i
As the waves tossed him around, Tim struggled to stay afloat, fighting the waves. Just when he thought he couldn't hold on any longer, a strong hand grabbed his wrist and pulled him to safety. It was the lighthouse keeper who had noticed him floundering from the shore.
.
w
q
EOF

cat chapter-01.md
git status
git add chapter-01.md
git commit -m "Solved conflict, merged keeper and floundering."
git log --graph --decorate --oneline

pause "CHECKPOINT — Conflicto resuelto"

echo "=== Alice: Tags ==="
git branch -d vocabulary-chapter-01
git branch
git log --graph --decorate --oneline

pause "CHECKPOINT snap04"

git tag v1
git log --oneline
ls .git/refs/tags
cat .git/refs/tags/v1
cat .git/refs/heads/main

git tag -d v1
ls .git/refs/tags
git tag -a v1 -m "First chapter is ready to be reviewed!"
ls .git/refs/tags
cat .git/refs/heads/main
cat .git/refs/tags/v1

cd ../../

pause "CHECKPOINT snap05 — Alice sale"

echo "=== Bob: Clonando repositorio ==="
mkdir -p bob
cd bob

git clone ../alice/book
ls
cd book
ls
git log --oneline

git remote
git remote get-url origin

git config user.name Bob
git config user.email bob@example.com

pause "CHECKPOINT snap06"

echo "=== Bob: Push a origin ==="

cat << EOF > chapter-02.md
Tim couldn't believe his luck. The stranger had saved his life, and he was filled with gratitude. "Thank you so much," he said, still panting from the ordeal. "I thought I was going to drown out there."

The lighthouse keeper smiled kindly at him. "You're welcome," he said. "But you should be more careful. The ocean can be dangerous, especially when there's a strong current like today."

Tim nodded, his heart still racing. He realized that he had underestimated the power of the ocean, and he felt humbled by the experience. From that moment on, he made a vow to always respect the sea and to never take its power for granted.

As they made their way back to the shore, the lighthouse keeper introduced himself as John, and they struck up a conversation. Tim learned that John had spent his life guiding ships safely through the treacherous waters of the coast. He was now enjoying his retirement in the nearby town, where he relished fishing and spending time with his grandchildren.

As they said their goodbyes, John turned to Tim with a twinkle in his eye. "Have you ever heard of the mermaids?" he asked, his voice filled with mystery
EOF

ls
git add chapter-02.md
git commit -m "Added chapter 2."
git log --oneline

git push origin main || echo ">>> ERROR ESPERADO: no se puede push a repo con working tree"

git checkout -b wip-chapter-02
git status
git push origin wip-chapter-02

cd ../../

pause "CHECKPOINT snap07 — Bob hizo push"

echo "=== Alice: Merge del branch de Bob ==="
cd alice/book
git status
ls
git branch
git merge wip-chapter-02
ls
git log --graph --oneline

git branch -d wip-chapter-02
git branch

cd ../../

pause "CHECKPOINT snap08"

echo "=== Alice: Repositorio centralizado (bare) ==="
mkdir central.git
cd central.git
git init --bare --shared
ls
cd ..

cd alice/book
git status
git remote add origin ../../central.git/
git push origin main
git push origin v1

pause "CHECKPOINT — Repo central creado"

echo "=== Alice: Nuevo capitulo ==="

cat << EOF > chapter-03.md
Tim woke up with a start, his heart racing and his body drenched in sweat; it took him a few moments to realize that he had been dreaming about the mermaids again. He had been having the same dream for weeks now - the mermaids would appear out of nowhere, their beautiful faces twisted into a sinister snarl as they dragged him under the water.

He knew it was silly to be afraid of something that didn't exist, but he couldn't shake the feeling that there was some truth to his dreams. The sea was full of mysteries and he had heard stories of sailors who had encountered strange creatures on their voyages. Perhaps there was more to his dreams than just his imagination.

As he lay in bed, trying to calm his racing thoughts, Tim made a decision. He would set out to learn as much as he could about the sea and the creatures that dwelled within it. If there was any truth to his dreams, he wanted to be prepared. And he knew where to start his investigation.
EOF

ls
git add chapter-03.md
git commit -m "New chapter"
git push origin main

cd ../..

pause "CHECKPOINT snap09"

echo "=== Bob: Pull desde central ==="
cd bob/book
git status
git checkout main

git remote
git remote get-url origin
git remote rename origin alice
git remote add origin ../../central.git/
git remote

git fetch origin main
git diff FETCH_HEAD

git pull origin main
git log --graph --decorate --oneline

cd ../..

pause "CHECKPOINT snap10 — WORKSHOP COMPLETO"

echo ""
echo "============================================"
echo "  Workshop Git finalizado exitosamente!"
echo "============================================"
echo ""
echo "Estructura final:"
ls -la $WORKDIR/
echo ""
echo "  alice/book  — Repo de Alice"
echo "  bob/book    — Repo de Bob"
echo "  central.git — Repo bare centralizado"
