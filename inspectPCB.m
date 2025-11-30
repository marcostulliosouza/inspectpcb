function inspectPCB()
% INSPECTPCB Sistema de inspeção de PCB para detecção de componentes faltantes
%   Exemplo de uso: inspectPCB()

    clc; clear all; close all;

    % Carregar imagens
    img = imread('images/0698.png');
    img_cinza = rgb2gray(img);

    % pré-processamento
    img_cont = imadjust(img_cinza);
    img_filt = medfilt2(img_cont, [3 3]);

    % referência
    pcb_template = imread("images/placa_sem_defeito.png");
    template_cinza = rgb2gray(pcb_template);

    % ajustar tamanho das imagens
    img_filt = imresize(img_filt, size(template_cinza));

    % detecção de componentes faltantes
    detectarComponentesFaltantes(img_filt, template_cinza);
end

function detectarComponentesFaltantes(img, template)
    % subtração das imagens
    diff_img = imabsdiff(img, template);
    
    % aumentar contraste das diferenças
    diff_enhanced = imadjust(diff_img);
    diff_bin = imbinarize(diff_enhanced, 0.4);
    
    % operações morfológicas mais agressivas
    se1 = strel('disk', 16);
    se2 = strel('rectangle', [10 10]);
    
    diff_clean = imopen(diff_bin, se1);
    diff_clean = imclose(diff_clean, se2);
    
    % remover pequenos ruídos
    diff_final = bwareaopen(diff_clean, 200);
    
    % encontrar regiões de diferença
    stats = regionprops(diff_final, 'BoundingBox', 'Area', 'Centroid');
    
    if ~isempty(stats)
        bboxes = vertcat(stats.BoundingBox);
        areas = [stats.Area];
        
        % agrupar regiões próximas
        merged_bboxes = mergeOverlappingBBoxes(bboxes, areas);
        
        figure;
        subplot(2,2,1); imshow(img); title('PCB com Defeito');
        subplot(2,2,2); imshow(template); title('PCB de Referência');
        subplot(2,2,3); imshow(diff_enhanced); title('Diferença Realçada');
        
        subplot(2,2,4); 
        imshow(img); 
        title('Problemas Detectados: ');
        hold on;
        
        % desenhar apenas as bounding boxes mescladas
        for i = 1:size(merged_bboxes, 1)
            bb = merged_bboxes(i,:);
            % Verificar se o bounding box é válido
            if numel(bb) == 4 && all(bb(3:4) > 0)
                rectangle('Position', bb, 'EdgeColor', 'r', 'LineWidth', 3);
                text(bb(1), bb(2)-15, num2str(i), 'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold');
            end
        end
        
        fprintf('Detectados %d problemas na PCB\n', size(merged_bboxes, 1));
    else
        fprintf('Nenhum problema detectado\n');
    end
end

function merged_bboxes = mergeOverlappingBBoxes(bboxes, areas)
    % função para mesclar bounding boxes sobrepostos
    if isempty(bboxes)
        merged_bboxes = [];
        return;
    end
    
    merged_bboxes = [];
    used = false(size(bboxes, 1), 1);
    
    for i = 1:size(bboxes, 1)
        if used(i), continue; end
        
        current_bb = bboxes(i,:);
        group_indices = i;
        
        % encontrar bounding boxes sobrepostos
        for j = i+1:size(bboxes, 1)
            if ~used(j) && bboxOverlapRatio(current_bb, bboxes(j,:)) > 0.3
                group_indices = [group_indices, j];
                used(j) = true;
            end
        end
        
        % mesclar o grupo
        group_bboxes = bboxes(group_indices,:);
        
        x1 = min(group_bboxes(:,1));
        y1 = min(group_bboxes(:,2));
        x2 = max(group_bboxes(:,1) + group_bboxes(:,3));
        y2 = max(group_bboxes(:,2) + group_bboxes(:,4));
        
        merged_bb = [x1, y1, x2-x1, y2-y1];
        
        % Garantir que o bounding box é válido
        if merged_bb(3) > 0 && merged_bb(4) > 0
            merged_bboxes = [merged_bboxes; merged_bb];
        end
        
        used(i) = true;
    end
    
    % Se não houve mesclagem, retorna os originais
    if isempty(merged_bboxes)
        merged_bboxes = bboxes;
    end
end