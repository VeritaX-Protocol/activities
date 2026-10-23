# activities

Espejo de la actividad de la organización **VeritaX-Protocol**. Cada commit de cada repositorio público de la organización se replica aquí, 1 a 1, como un commit vacío:

- mensaje: `[repo] asunto original` (solo la primera línea del mensaje);
- autor y fecha: los del commit original;
- cuerpo: `Source: VeritaX-Protocol/repo@sha`, que evita duplicados.

Sirve para que herramientas que solo leen un repositorio (como Apex) vean la actividad de toda la organización apuntando a este.

## Cómo se actualiza

El workflow [`sync`](.github/workflows/sync.yml) corre cada 30 minutos (y a mano con *Run workflow*). Ejecuta [`scripts/sync.sh`](scripts/sync.sh), que crea los commits que faltan y termina con una verificación: por repo, los espejos deben ser al menos tantos como commits tiene el original.

Reglas: `activities` no se replica a sí mismo; solo se replican repos públicos; los repos nuevos entran solos.

Local: `scripts/sync.sh` (requiere `gh` autenticado) o `scripts/sync.sh verificar`.
