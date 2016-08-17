require_relative '../service/processar_pacotes.rb'
require_relative '../service/separar_medida_equipamento.rb'
require_relative '../service/alarme_normalizacao.rb'
class Pacotes
  def self.processador(pacote)
    tipo_pacote = ProcessarPacotes::obtem_tipo_pacote pacote

    case tipo_pacote.to_i
    when PERIODICO_OK
      logger.info "="*20
      logger.info("Periódico OK")
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            medidas = ProcessarPacotes.leituras_instantanea pacote
            pacote_equipamento = SepararMedidaEquipamento.obter_pacote_equipamento medidas
            Evento.persistir_evento pacote_equipamento
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir Periódico OK #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
      logger.info "="*20

    when CONFIRMACAO_COMANDOS
      logger.info "="*20
      logger.info("Confirmação de comando recebido da telemetria #{pacote}")

      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            ProcessarPacotes.processa_confirmacao_comandos pacote
          end
        rescue Expection => e
          logger.fatal "Erro ao persistir, confirmação na tabela de saída #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
      logger.info "="*20

    when PERIODICO_ALARMADO
      logger.info "="*20
      logger.info("Periódico Alarmado")
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            medidas = ProcessarPacotes.leituras_instantanea pacote
            pacote_equipamento = SepararMedidaEquipamento.obter_pacote_equipamento medidas
            Evento.persistir_evento pacote_equipamento
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir Periódico Alarmado #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
      logger.info "="*20

    when CONFIGURACAO
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            logger.info "="*20
            logger.info ("Configuração")
            ProcessarPacotes.configuracao pacote
            logger.info "="*20
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir Configuração #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
    when INICIALIZACAO
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            logger.info "="*20
            logger.info ("Inicialização")
            pacote_processado = ProcessarPacotes.inicializacao pacote
            unless pacote_processado.blank?
              pacote_equipamentos = SepararMedidaEquipamento.obter_pacote_equipamento pacote_processado
              Evento.persistir_inicializacao pacote_equipamentos, pacote_processado unless pacote_equipamentos.blank?
            end
            logger.info "="*20
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir Inicialização #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
    when LEITURA_INSTANTANEA
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            logger.info "="*20
            logger.info("Leitura Instantânea")
            medidas = ProcessarPacotes.leituras_instantanea pacote
            pacote_equipamento = SepararMedidaEquipamento.obter_pacote_equipamento medidas
            Evento.persistir_evento pacote_equipamento
            logger.info "="*20
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir leitura instantanea #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
    when CONTAGEM_ALARMAR
      logger.info "="*20
      print('Em contagem para alarmar')
      logger.info "="*20

    when NORMALIZACAO
      logger.info "="*20
      logger.info("Restauração Instantânea")
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            medidas = ProcessarPacotes.leituras_instantanea pacote
            if medidas.present?
              pacote_equipamento = SepararMedidaEquipamento.obter_pacote_equipamento medidas
              if pacote_equipamento.present?
                novo_pacote_equipamento = AlarmeNormalizacao.new({pacote: pacote_equipamento}).detectar_alteracao
                if novo_pacote_equipamento.present?
                  Evento.persistir_evento novo_pacote_equipamento
                  end
              end
            end
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir Restauração Instantânea #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
      logger.info "="*20

    when ALARME_INSTANTANEO
      logger.info "="*20
      logger.info("Alarme Instantâneo")
      Thread.new do
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            medidas = ProcessarPacotes.leituras_instantanea pacote
            if medidas.present?
              pacote_equipamento = SepararMedidaEquipamento.obter_pacote_equipamento medidas
              if pacote_equipamento.present?
                novo_pacote_equipamento = AlarmeNormalizacao.new({pacote: pacote_equipamento}).detectar_alteracao
                if novo_pacote_equipamento.present?
                  Evento.persistir_evento novo_pacote_equipamento
                end
              end
            end
          end
        rescue Exception => e
          logger.fatal "Erro ao persistir Alarme Instantâneo #{e}".red
          logger.fatal "Exception aconteceu em: #{e.backtrace[0]}".red
        end
      end
      logger.info "="*20

    when ID_RECEBIDO
      logger.info "="*20
      logger.info "ID RECEBIDO <#{pacote}>"
      logger.info "="*20

    else
      logger.info "pacote tipo: #{tipo_pacote}, ainda não suportado pelo WebService".yellow
    end
  end

  def self.formatador(pacote)
    pacote = pacote.chomp
    pacote = pacote.tr!('<', '')
    pacote = pacote.tr!('>', '')
  end

  def self.pacote_is_valido(pacote)
    package_is_valid = false
    pacote_recebido = ''
    # Validação do codigo da telemetria / chaves / tamanho minimo
    package_is_valid =
      if pacote.present? && pacote.chars.first == '<' && pacote.chars.last == '>' && pacote.size >= 6
        pacote_recebido = Pacotes.formatador pacote
        codigo_telemetria = ProcessarPacotes.obtem_codigo_telemetria(pacote_recebido)
        /^\d{4}$/ === codigo_telemetria
      end

    if package_is_valid && pacote_recebido.present?
      package_is_valid =
        if pacote_recebido.size == SIZE_ID_TELEMETRIA
          true
        elsif ProcessarPacotes.obtem_codigo_telemetria(pacote_recebido).to_i == 0
          true
        else
          Pacotes.validar_tipo_pacote pacote_recebido
        end
    end

    package_is_valid
  end

  def self.validar_tipo_pacote(pacote)
    package_type_is_valid = false
    tipo_pacote = ProcessarPacotes.obtem_tipo_pacote(pacote)
    package_type_is_valid  = /^\d{2}$/ === tipo_pacote

    package_type_is_valid =
      if package_type_is_valid
        Pacotes.validar_tipo_tamanho_pacote pacote
      else
        false
      end
  end

  def self.validar_tipo_tamanho_pacote(pacote)
    package_length_is_valid = false
    tipo_pacote = ProcessarPacotes.obtem_tipo_pacote(pacote)
    package_length_is_valid =
      case tipo_pacote.to_i
      when PERIODICO_OK # 72
        pacote.size == SIZE_PERIODICO_OK ? true : false
      when ALARME_INSTANTANEO, NORMALIZACAO, LEITURA_INSTANTANEA, INICIALIZACAO, PERIODICO_ALARMADO # 88 caracteres
        pacote.size == SIZE_PACOTES_DEFAULT ? true : false
      when CONFIGURACAO # 190
        pacote.size == SIZE_CONFIGURACAO ? true : false
      when CONFIRMACAO_COMANDOS #12
          pacote.size == SIZE_CONFIRMACAO_COMANDOS ? true : false
          if pacote.size == SIZE_CONFIRMACAO_COMANDOS or pacote.size == SIZE_CONFIRMACAO_IP_PORTA_HOST
            true
          else
            false
          end
      else
        false
      end
  end

end
