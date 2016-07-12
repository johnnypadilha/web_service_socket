class AlarmeNormalizacao
  attr :pacote

  def initialize(args = {})
    @pacote = args[:pacote]
  end

  def detectar_alteracao
    medidas_eventos_colecao = []
    novo_pacote = []
    pacote.each do |pack|
      equipamento = Equipamento.find(pack[:id_equipamento])

      equipamento.medidas_equipamento(pack).each do |medida|
        faixa_atual = medida.faixas.select {|s| s.minimo.to_i >= pack[medida.codigo_medida.to_sym].to_i && s.maximo.to_i <= pack[medida.codigo_medida.to_sym].to_i}.first
        status_faixa = faixa_atual.present? ? faixa_atual.status_faixa : ALARME

        medida_evento = {
                          medida_id: medida.id,
                          valor: pack[medida.codigo_medida.to_sym],
                          status_faixa: status_faixa,
                          codigo_medida: medida.codigo_medida
                        }

        medidas_eventos_colecao << medida_evento
      end

      ultimas_medidas_evento = MedidasEvento.obter_ultimas_medidas_evento medidas_eventos_colecao

      mudou_faixa, tipo_pacote = AlarmeNormalizacao.detecta_mudanca_faixa ultimas_medidas_evento, medidas_eventos_colecao

      if mudou_faixa
        codigo_pacote = AlarmeNormalizacao.obter_tipo_pacote tipo_pacote, medidas_eventos_colecao
        pack[:tipo_pacote] = codigo_pacote
        novo_pacote << pack
      end
    end

    p novo_pacote
  end

  def self.detecta_mudanca_faixa(ultimas_medidas_evento, medidas_colecao)
    tipo_pacote = 0
    mudou_faixa = false
    ultimas_medidas_evento.each do |medida_anterior|
      medidas_colecao.each do |medida_atual|
        if medida_atual[:medida_id].to_i == medida_anterior.medida_id
          unless medida_atual[:status_faixa].to_i == medida_anterior.status_faixa.to_i
            mudou_faixa = true
            case medida_atual[:status_faixa].to_i
            when OK
              tipo_pacote = PACOTE_NORMALIZACAO unless tipo_pacote == PACOTE_ALERTA || tipo_pacote == PACOTE_ALARME
            when ALERTA
              tipo_pacote = PACOTE_ALERTA unless tipo_pacote == PACOTE_ALARME
            when ALARME
              'ENTROU EM ALARME'
              tipo_pacote = PACOTE_ALARME
            end
          end
        end
      end
    end

    return mudou_faixa, tipo_pacote
  end


  def self.obter_tipo_pacote(tipo_pacote, pacote)
    medidas_em_alarme = pacote.select {|s| s[:status_faixa].to_i == ALARME}
    medidas_em_alerta = pacote.select {|s| s[:status_faixa].to_i == ALERTA}
    medidas_normalizadas = pacote.select {|s| s[:status_faixa].to_i == OK}
    case tipo_pacote.to_i
    when PACOTE_NORMALIZACAO
      tipo_pacote = PACOTE_NORMALIZACAO_ALERTA if medidas_em_alerta.present?
      tipo_pacote = PACOTE_NORMALIZACAO_ALARME if medidas_em_alarme.present?
    when PACOTE_ALERTA
      tipo_pacote = PACOTE_ALERTA_ALARME if medidas_em_alarme.present?
      tipo_pacote = PACOTE_ALERTA_OK if medidas_normalizadas.present?
    end

    tipo_pacote
  end
end