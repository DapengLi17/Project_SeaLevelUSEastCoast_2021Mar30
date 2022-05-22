function set_up_ssh_data(NetCDF_files_path, ssh_NetCDF_name, lat_NetCDF_name, lon_NetCDF_name, ssh_save_path)
% Inputs:
%   NetCDF_files_path: The directory path to the NetCDF files.
%   ssh_NetCDF_name: The name of the variable inside the NetCDF file that
%                    corresponds to the SSH data.
%   lat_NetCDF_name: The name of the variable inside the NetCDF file that
%                    corresponds to the latitude data.
%   lon_NetCDF_name: The name of the variable inside the NetCDF file that
%                    corresponds to the longitude data.
%   ssh_save_path: The directory where you want resulting SSH, latitude,
%                  longitude, and other .mat data that is generated by this
%                  function saved.
%
% If you do not understand how to provide these inputs, please refer to the
% NetCDF data files you have, and check the variable names by running
% either 'ncdump -h <nc_filename>' in a terminal, or by using MATLAB's
% built in 'ncdisp(<nc_filename>)' command to read about the variable
% names.

if ~strcmp(NetCDF_files_path(end), '/')
    NetCDF_files_path = strcat(NetCDF_files_path, '/');
end
if ~strcmp(ssh_save_path(end), '/')
    ssh_save_path = strcat(ssh_save_path, '/');
end
if ~exist(ssh_save_path, 'dir')
    mkdir(ssh_save_path);
end
disp('Generating dates.');
dates = generate_dates_nc(NetCDF_files_path);%#ok
save([ssh_save_path, 'dates.mat'], 'dates');
disp('Getting latitude and longitude information.');
[lat, lon] = get_lat_and_lon(NetCDF_files_path, lat_NetCDF_name, lon_NetCDF_name);
save([ssh_save_path, 'lat.mat'], 'lat');
save([ssh_save_path, 'lon.mat'], 'lon');
disp('Generating area map.');
lat_bnds = create_bounds_for_lat_from_number(length(lat));
lon_bnds = create_bounds_for_lon_from_number(length(lon));
area_map = gen_area_map(lat_bnds, lon_bnds);%#ok
save([ssh_save_path, 'area_map.mat'], 'area_map'); 
disp('Extracting SSH data from NetCDF files.');
extract_ssh_data(NetCDF_files_path, ssh_NetCDF_name, lat, lon, ssh_save_path);
end

function par_save(filename, data)%#ok
save(filename, 'data');
end

function lat_save(filename, lat)%#ok
save(filename, 'lat');
end

function lon_save(filename, lon)%#ok
save(filename, 'lon');
end

function [lat, lon] = get_lat_and_lon(NetCDF_files_path, lat_name, lon_name)
files = dir(NetCDF_files_path);
for i = 1:length(files)
    if files(i).isdir && ~isequal(files(i).name, '.') && ~isequal(files(i).name, '..')
        get_lat_and_lon([NetCDF_files_path, files(i).name, '/'], lat_name, lon_name);
        continue;
    end
    file = files(i).name;
    [~, ~, ext] = fileparts([NetCDF_files_path, file]);
    if strcmp(ext, '.nc')
        lat = ncread([NetCDF_files_path, file], lat_name);
        lon = ncread([NetCDF_files_path, file], lon_name);
        if ~isa(lat, 'double')
            lat = double(lat);
        end
        if ~isa(lon, 'double')
            lon = double(lon);
        end
        return;
    end
end
end

function extract_ssh_data(NetCDF_files_path, ssh_NetCDF_name, lat, lon, ssh_save_path)
files = dir(NetCDF_files_path);
parfor i = 1:length(files)
    if files(i).isdir && ~isequal(files(i).name, '.') && ~isequal(files(i).name, '..')
        extract_ssh_data([NetCDF_files_path, files(i).name, '/']);
        continue;
    end
    file = files(i).name;
    [~, name, ext] = fileparts([NetCDF_files_path, file]);
    if strcmp(ext, '.nc')
        ssh = ncread([NetCDF_files_path, file], ssh_NetCDF_name);
        [x, y] = size(ssh);
        if x == length(lon) && y == length(lat)
            ssh = ssh';
        end
        indices = regexp(name, '[0-9]');
        numbers = name(indices);
        date = numbers(1:8);
        par_save([ssh_save_path, 'ssh_', date, '.mat'], ssh);
    end
end
end

function [dates] = generate_dates_nc(path)
if ~strcmp(path(end), '/')
    path = strcat(path, '/');
end
files = dir(path);
x = 0;
for i = 1:length(files)
    if ~isempty(strfind(files(i).name, 'dt_global_'))
        x = x + 1;
    end
end
dates = zeros(x, 1);
x = 1;
for i = 1:length(files)
    if files(i).isdir && ~isequal(files(i).name, '.') && ~isequal(files(i).name, '..')
        disp(['File name ', files(i).name]);
        rec_dates = generate_dates_nc([path, files(i).name, '/']);
        for j = 1:length(rec_dates)
            dates(x) = rec_dates(j);
            x = x + 1;
        end
        continue;
    end
    file = files(i).name;
    [~, ~, ext] = fileparts([path, file]);
    if strcmp(ext, '.nc')
        vals = regexp(file, '[0-9]');
        date = file(vals);
        date = date(1:8);
        date = str2double(date);
        dates(x) = date;
        x = x + 1;
    end
end
end

function [lat_bounds] = create_bounds_for_lat_from_number(lat_number)
lat_bounds = zeros(2,lat_number);
lat_bounds(1,1) = -90;
coeff = 180 / lat_number;
for i = 1:lat_number-1
    lat_bounds(2,i) = lat_bounds(1,i) + coeff;
    lat_bounds(1,i+1) = lat_bounds(2,i);
end
lat_bounds(2,lat_number) = 90;
end

function [lon_bounds] = create_bounds_for_lon_from_number(lon_number)
lon_bounds = zeros(2,lon_number);
lon_bounds(1,1) = 0;
coeff = 360 / lon_number;
for i = 1:lon_number-1
    lon_bounds(2,i) = lon_bounds(1,i) + coeff;
    lon_bounds(1,i+1) = lon_bounds(2,i);
end
lon_bounds(2,lon_number) = 360;
end

function [area_map] = gen_area_map(lat_bnds, lon_bnds)
% Returns an area map for the given latitude and longitude bounds
area_map = zeros(length(lat_bnds), 1);
lon1 = lon_bnds(1,1);
lon2 = lon_bnds(1,2);
earth_ellipsoid = referenceSphere('earth', 'km');
for i = 1:length(lat_bnds)
    area_map(i) = areaquad(lat_bnds(1,i), lon1, lat_bnds(2,i), lon2, earth_ellipsoid);
end
end