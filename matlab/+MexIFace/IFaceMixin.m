% IFaceMixin.m
%
% Mark J. Olah (mjo@cs.unm DOT edu)
% 2014 - 2017
% copyright: see LICENCE file
%
% A mixin class that is to be inherited from for classes that conform to the Mex_Iface matlab<--->C++ Class interface

classdef IFaceMixin < handle
    properties (Access = protected)
        % ifaceHandle - Function Handle to the Matlab class which is the interface
        ifaceHandle;
        % objectHandle - Numeric scalar uint64 that represents a C++ Handle object that itself holds the persistant C++ object we are associated with
        objectHandle=uint64(0);
    end

    methods (Access=public)
        %% Destructor
        function delete(obj)
            obj.closeIface();
        end
    end

    methods (Access=protected)
        function obj = IFaceMixin(ifaceHandle)
            % Inputs:
            %  ifaceHandle - A function handle to the *_Iface mex function that implements the C++ side of the interface
            obj.ifaceHandle = ifaceHandle;
        end

        function success=openIface(obj, varargin)
            % Make a new C++ object and save the numeric handle to the allocated object
            %
            % Inputs:
            %  varargin - These are the inputs the iface @new command expects.  They are passed directly though
            % Ouput:
            %  success - True if we were able to make a peristant C++ object and are now ready for calling methods.
            if obj.objectHandle
                error([class(obj) ':call'],'objectHandle already exists and is non 0. Cannot create new ifaceobject until current object is closed.');
            end
%             try 
                obj.objectHandle = obj.ifaceHandle('@new', varargin{:});
%             end
             
            success= obj.objectHandle>0;
        end

        function closeIface(obj)
            % Close the iface and release the objectHandle and free the memory on the C++ side
            if obj.objectHandle
                obj.call('@delete');
                obj.objectHandle=uint64(0);
            end
        end

        function varargout=call(obj, cmdstr, varargin)
            % This is the entry point to call a method of the underlying C++ class.  The Matlab side of the wrapped class
            % should internally call this protected method to call member functions of the C++ class.
            %
            % Inputs:
            %  cmdstr - This is charactor array giving the name of the method to call
            %  varargin - The rest of the arguments the method expects.  These are passed directly in.
            % Output:
            %  varargout - Whatever arguments the method is supposed to return.  These are passed back directly
            if ~obj.objectHandle && ~obj.openIface()
                error([class(obj) ':call'],'objectHandle not valid and could not be created.');
            end
            [varargout{1:nargout}]=obj.ifaceHandle(cmdstr,obj.objectHandle, varargin{:});
        end
    end %Protected methods

    methods (Access=protected, Static=true)
        function varargout=callstatic(ifaceHandle, cmdstr, varargin)
            % callstatic   The entry point to call a static method of the underlying C++ class.  The Matlab side of the wrapped class
            % should internally call this protected method to call static member functions of the C++ class.  Because these are
            % static methods there is no need to have an active intantiation of the C++ class in objectHandle.
            %
            % The user must provide the ifaceHandle directly, since we won't have an instantiated matlab object from which to get ifaceHandle
            %
            % Inputs:
            %  ifaceHandle - This is the function pointer to the mex *_Iface function that provides the C++ side of the interface
            %  cmdstr - This is charactor array giving the name of the method to call
            %  varargin - The rest of the arguments the method expects.  These are passed directly in.
            % Output:
            %  varargout - Whatever arguments the method is supposed to return.  These are passed back directly
            [varargout{1:nargout}]=ifaceHandle('@static',cmdstr, varargin{:});
        end

        function structDict = convertStatsToStructs(statsDict)
            % convertStatsToStructs   Convert a stats dictionary returned from C++ to a structured stats dictionary, i.e., a 
            % structure of structres.  Entries like "group.param1", "group.param2" are turned into
            % sub - structures.
            % [in] statsDict - structure mapping parameter names to values
            % [out] structDict - a more structured representation of the same dictionary
            fullnames = fieldnames(statsDict);
            names = MexIFace.cellmap(@(n) strsplit(n,'.'),fullnames);
            dictname_idxs = cellfun(@numel, names)==2;
            dictnames = unique(MexIFace.cellmap(@(n) n{1}, names(dictname_idxs)));
            structDict = cell2struct(cell(1,numel(dictnames)),dictnames,2);
            
            for n=1:numel(names)
                name = names{n};
                val = statsDict.(fullnames{n});
                if dictname_idxs(n)
                    num = str2num(name{2}); %#ok<ST2NM>
                    if ~isempty(num) && isfinite(num) && mod(num,1)==0.
                        if ~isnumeric(structDict.(name{1}))
                            c = zeros(num,1);
                            c(num) = val;
                            structDict.(name{1}) = c;
                        else
                            c=structDict.(name{1});
                            c(num) = val;
                            structDict.(name{1}) = c;
                        end
                    else
                        if ~isempty(structDict.(name{1})) && ~isstruct(structDict.(name{1})) 
                            error('IFaceMixin:convertStatsToStructs','Mixed indexes and names for sub-struct/array');
                        end
                        structDict.(name{1}).(name{2}) = val;
                    end
                else
                    structDict.(name{1}) = val;
                end
            end
        end
    end % Protected static methods
end