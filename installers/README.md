# Pacotes de instalação

Os pacotes **não ficam no repositório**: eles são gerados automaticamente e
publicados na página **Releases** do GitHub sempre que a versão muda (veja
[docs/publicar-versao.md](../docs/publicar-versao.md)).

Para gerar localmente:

```bash
bash scripts/common/fetch-tools.sh
bash scripts/common/build-packages.sh
```
