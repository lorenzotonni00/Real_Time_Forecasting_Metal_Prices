function codes = transformations_for_ids(transformations, ids, label)

if nargin < 3
    label = 'transformations';
end

if isstring(ids)
    ids = cellstr(ids);
elseif ischar(ids)
    ids = cellstr(ids);
end

if isnumeric(transformations)
    codes = transformations(:)';
    if numel(codes) ~= numel(ids)
        error('%s must have %d entries, one for each series id.', label, numel(ids));
    end
    return
end

codes = nan(1, numel(ids));
missing_ids = {};

if isstruct(transformations)
    for ii = 1:numel(ids)
        id = ids{ii};
        valid_id = matlab.lang.makeValidName(id);

        if isfield(transformations, id)
            code = transformations.(id);
        elseif isfield(transformations, valid_id)
            code = transformations.(valid_id);
        else
            missing_ids{end+1} = id; %#ok<AGROW>
            continue
        end

        validate_transform_code(code, label, id);
        codes(ii) = code;
    end
elseif isa(transformations, 'containers.Map')
    for ii = 1:numel(ids)
        id = ids{ii};

        if ~isKey(transformations, id)
            missing_ids{end+1} = id;
            continue
        end

        code = transformations(id);
        validate_transform_code(code, label, id);
        codes(ii) = code;
    end
else
    error('%s must be a numeric vector, struct, or containers.Map.', label);
end

if ~isempty(missing_ids)
    error('%s is missing transformation codes for: %s', label, strjoin(missing_ids, ', '));
end

end

function validate_transform_code(code, label, id)

if ~isnumeric(code) || ~isscalar(code) || isnan(code)
    error('%s.%s must be a numeric scalar transformation code.', label, id);
end

end
