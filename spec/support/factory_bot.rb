# Sem isto, `build(:model)` propaga a estratégia `build` para associações
# implícitas (ex.: `host` em uma trait), deixando o registro associado sem id
# e, portanto, a foreign key (ex.: `host_id`) nula mesmo quando a associação
# foi atribuída. Voltamos ao comportamento pré-5.0: associações implícitas
# sempre usam `create`, independente da estratégia do pai.
FactoryBot.use_parent_strategy = false
