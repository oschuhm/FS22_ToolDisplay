--
-- Insert specializations into vehicleType's
--
--
-- @author:    	Xentro (Marcus@Xentro.se)
-- @website:	www.Xentro.se
-- @history:	v3.0 - 2018-11-27 - Farming Simulator 19
--				v3.1 - 2019-01-27 - Correction for multiple specializations and remove l10n registration // Ralf08
--              v4.0 - 2022-04-01 - Update for LS22 // LS-Farmers

AddSpecialization = {
	specializationToAdd = {},
	printHeader 	= "Add Specialization ( %s ) - %s: %s";
	
	RES_REQUIRED	= 0,
	RES_NOT_ALLOWED	= 1,
	
	-- Debug text
	MES_FOUND_REQUIRED 	  = "Found.",
	MES_FOUND_NOT_ALLOWED = "Aren't allowed.",
	MES_MISSING 		  = "Missing."
};


function AddSpecialization:loadXMLModDesc()
	local xmlFile = loadXMLFile("AddSpecializationModDesc", Utils.getFilename("modDesc.xml", g_currentModDirectory));

	local i = 0;
	while true do
		local key = string.format("modDesc.addSpecialization.specialization(%d)", i);
		if not hasXMLProperty(xmlFile, key) then break; end;
		
		local name 			= getXMLString(xmlFile, key .. "#name");
		local className 	= getXMLString(xmlFile, key .. "#className");
		local filename 		= getXMLString(xmlFile, key .. "#filename");
		
		
		if name ~= nil and className ~= nil and filename ~= nil then
			local filename = Utils.getFilename(filename, g_currentModDirectory);
			
			if fileExists(filename) then
				print(string.format(AddSpecialization.printHeader, name, "Info", "File found " .. filename));
				local entry = {
					name 			 = name,
					className 		 = className,
					filename 		 = filename,
					debug 	 		 = Utils.getNoNil(getXMLBool(xmlFile, key .. "#debug"), false),
					vehicleTypeLimit = AddSpecialization:loadXMLTable(xmlFile, key, "vehicleTypeLimit", getXMLBool),
					restrictions	 = AddSpecialization:loadXMLTable(xmlFile, key, "restrictions", 	getXMLInt),
					searchWords		 = AddSpecialization:loadXMLTable(xmlFile, key, "searchWords", 		getXMLInt)
				};
				
				table.insert(AddSpecialization.specializationToAdd, entry);
			else
				print(string.format(AddSpecialization.printHeader, name, "Info", "File don't exist " .. filename));
			end;
		end;
		
		i = i + 1;
	end;
	--DebugUtil.printTableRecursively(AddSpecialization.specializationToAdd,".",0,5);
	delete(xmlFile);
end;

function AddSpecialization:loadXMLTable(xmlFile, k, t, f)
	local entry = {};
	local i = 0;
	while true do
		local key = string.format(k .. "." .. t .. "(%d)", i);
		if not hasXMLProperty(xmlFile, key) then break; end;
		
		local state = f(xmlFile, key .. "#state");
		local name  = getXMLString(xmlFile, key .. "#name");
		
		if state ~= nil and name ~= nil then
			if t == "vehicleTypeLimit" then
				entry[name] = state;
			else
				table.insert(entry, {name, state});
			end;
		end;
		
		i = i + 1;
	end;
	
	return entry;
end;

function AddSpecialization:add(ss)
	local currentTypeCount 	= {0, 0}; -- Current, Total
	local isEmpty 			= true;
	local passState 		= false;
			
	for name, v in pairs(ss.vehicleTypeLimit) do
		isEmpty = false;
		
		if not v then
			passState = true;  -- If only false then let all types which haven't been setup pass.
		else
			passState = false; -- If we got both True/False then only allow those that are set to true.
			break;
		end;
	end;
		
    for vehicleType, vehicle in pairs(g_vehicleTypeManager.types) do
		if vehicle ~= nil then
				currentTypeCount[2] = currentTypeCount[2] + 1;
			
			if (isEmpty 																						-- VehicleType search is empty, let it pass
			or not passState and ss.vehicleTypeLimit[vehicleType] ~= nil and ss.vehicleTypeLimit[vehicleType]	-- Check True / False state and let pass according
			or passState and ss.vehicleTypeLimit[vehicleType] ~= nil and ss.vehicleTypeLimit[vehicleType]		-- Only false vehicleType's have been set, let all which aren't set to False pass
			or passState and ss.vehicleTypeLimit[vehicleType] == nil) then
				local currentLimitCount = {0, 0}; -- Found, Total
				local debugMessage 		= {};
				local forceStop 		= false;
					
				for _, r in ipairs(ss.restrictions) do
					if r[2] == AddSpecialization.RES_REQUIRED then
						currentLimitCount[2] = currentLimitCount[2] + 1;
					end;
						
					for vs in pairs(vehicle.specializationsByName) do
						if vs:lower() == r[1]:lower() then
							if r[2] == AddSpecialization.RES_REQUIRED then
								currentLimitCount[1] = currentLimitCount[1] + 1;
								debugMessage[r[1]] = AddSpecialization.MES_FOUND_REQUIRED;
									
							elseif r[2] == AddSpecialization.RES_NOT_ALLOWED then
								debugMessage[r[1]] = AddSpecialization.MES_FOUND_NOT_ALLOWED;
								forceStop = true;
							end;
								
							break; -- We found our target, stop this loop
						end;
					end;
				end;
				
				-- Do name check of specializations
				if not forceStop then
					for _, sw in ipairs(ss.searchWords) do
						if sw[2] == AddSpecialization.RES_REQUIRED then
							currentLimitCount[2] = currentLimitCount[2] + 1;
						end;
						
						for name in pairs(vehicle.specializationsByName) do
							if string.find(name:lower(), sw[1]:lower()) ~= nil then
								if sw[2] == AddSpecialization.RES_REQUIRED then
									currentLimitCount[1] = currentLimitCount[1] + 1;
									debugMessage[name] = AddSpecialization.MES_FOUND_REQUIRED;
								
								elseif sw[2] == AddSpecialization.RES_NOT_ALLOWED then
									debugMessage[name] = AddSpecialization.MES_FOUND_NOT_ALLOWED;
									forceStop = true;
								end;
								
								debugMessage[name] = debugMessage[name] .. " Search Word: " .. sw[1];
								
								break;
							end;
						end;
					end;
				end;
					
				-- Do some-- prints
				if (currentLimitCount[1] ~= currentLimitCount[2] or forceStop) then
					if ss.debug then
						print(string.format(AddSpecialization.printHeader, ss.name, "Info", "Found ( " .. currentLimitCount[1] .. " / " .. currentLimitCount[2] .. " ) of the required specialization's in " .. vehicleType));
						print(string.format(AddSpecialization.printHeader, ss.name, "Info", "List of specialization's"));
						
						if currentLimitCount[1] ~= currentLimitCount[2] then
							for _, r in ipairs(ss.restrictions) do
								if debugMessage[r[1]] == nil and r[1] ~= ss.name then
									print(string.format(AddSpecialization.printHeader, ss.name, "Info", r[1] .. " " .. AddSpecialization.MES_MISSING));
								end;
							end;
						end;
							
						for name, t in pairs(debugMessage) do
							print(string.format(AddSpecialization.printHeader, ss.name, "Info", name .. " " .. t));
						end;
					end;
					
					forceStop = true;
				end;
					
				-- We passed the checks, add script
				if not forceStop then
					local obj = g_specializationManager:getSpecializationObjectByName(ss.name);
						
					vehicle.specializationsByName[ss.name] = obj;
					table.insert(vehicle.specializationNames, ss.name);
					table.insert(vehicle.specializations, obj);
					
					currentTypeCount[1] = currentTypeCount[1] + 1;
						
					if ss.debug then
						print(string.format(AddSpecialization.printHeader, ss.name, "Info", "Inserted on " .. vehicleType));
					end;
				end;
			end;
		end;
	end;
		
	print(string.format(AddSpecialization.printHeader, ss.name, "Info", "We have successfully added specialization Into ( " .. currentTypeCount[1] .. " / " .. currentTypeCount[2] .. ") of the vehicleTypes."));

end;

-- This can be replaced with an table too if that is much more preferred.
AddSpecialization:loadXMLModDesc();


for i, ss in ipairs(AddSpecialization.specializationToAdd) do
	-- Add specialization name to not allowed
	table.insert(ss.restrictions, {ss.name, AddSpecialization.RES_NOT_ALLOWED});
	table.insert(ss.searchWords,  {ss.name, AddSpecialization.RES_NOT_ALLOWED});

	
	if g_specializationManager:getSpecializationByName(ss.name) == nil then
		g_specializationManager:addSpecialization(ss.name, ss.className, ss.filename, true, nil);
	
		-- Key functions are called early so we need to add the specialization before it gets to that stage.
		AddSpecialization:add(ss);
	else
		print(string.format(AddSpecialization.printHeader, ss.name, "Error", "Specialization have been loaded already by another mod! This process will stop now."));
	end;
end;
