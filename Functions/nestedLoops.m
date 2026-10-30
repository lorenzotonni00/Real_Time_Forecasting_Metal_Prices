function allIndices = nestedLoops(Pn, n,  currentIndex, indices, allIndices)
    if currentIndex > n
        allIndices = [allIndices; indices];
    else
        for i = 1:Pn
            indices(currentIndex) = i;
            allIndices = nestedLoops(Pn, n, currentIndex + 1, indices, allIndices);
        end
    end
end