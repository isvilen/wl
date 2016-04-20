-module(wl_cursor).
-export([themes/0, load/3]).

-include_lib("wl/include/wl_cursor.hrl").

-include_lib("kernel/include/file.hrl").

-define(PATH,"~/.icons:/usr/share/icons:/usr/share/pixmaps").

-define(MAX_CURSOR_NAME,30).

-define(FILE_MAJOR,1).
-define(FILE_MINOR,0).
-define(FILE_VER,((?FILE_MAJOR bsl 16) bor ?FILE_MINOR)).
-define(FILE_HDR_LEN,(4 * 4)).
-define(FILE_TOC_LEN,(3 * 4)).

-define(CHUNK_HDR_LEN,(4 * 4)).

-define(IMAGE_TYPE,16#fffd0002).
-define(IMAGE_HDR_LEN,(?CHUNK_HDR_LEN + (5*4))).
-define(IMAGE_VER,1).
-define(IMAGE_MAX_DIM,32767).

-define(LU32(V),V:32/little-unsigned).


themes() ->
    lists:map(fun theme_info/1, themes_and_dirs()).

theme_info({Name, Dir}) ->
    Names = cursors_names(Dir),
    {Name, cursors_sizes(Dir, Names), [list_to_atom(N) || N <- Names]}.

themes_and_dirs() ->
    Paths = string:tokens(os:getenv("XCURSOR_PATH", ?PATH), ":"),
    lists:flatmap(fun (Path) -> themes_and_dirs(Path) end, Paths).

themes_and_dirs(Path) ->
    Ds = [D || D <- filelib:wildcard(expand_path(Path,"*")), filelib:is_dir(D)],
    lists:flatmap(fun theme_and_dir/1, Ds).

theme_and_dir(Path) ->
    Dir = filename:join(Path, "cursors"),
    case filelib:is_dir(Dir) of
        true  -> [{filename:basename(Path), Dir}];
        false -> inherited_themes(Path)
    end.


cursors_names(Dir) ->
    Files = filelib:wildcard(filename:join(Dir, "*")),
    lists:filtermap(fun cursors_name/1, Files).

cursors_name(File) ->
    case is_regular_or_symlink(File) of
        true ->
            case filename:basename(File) of
                N when length(N) < ?MAX_CURSOR_NAME -> {true, N};
                _                                   -> false
            end;
        false ->
            false
    end.


cursors_sizes(Dir, Names) ->
    Sizes = lists:foldl(fun (N, Acc) -> cursor_size(Dir, N, Acc) end,
                        sets:new(), Names),
    lists:sort(sets:to_list(Sizes)).


cursor_size(Dir, Name, Sizes) ->
    Path = filename:join(Dir, Name),
    case file:open(Path, [raw, binary]) of
        {ok, IoDev} ->
            try
                Tocs = load_tocs(IoDev),
                lists:foldl(fun ({Sz,_}, Acc) -> sets:add_element(Sz, Acc) end,
                            Sizes, Tocs)
            catch
                _:_ -> error({invalid_cursor_file, Path})
            after
                file:close(IoDev)
            end;
        {error, Reason} ->
            error({load_cursor_error, Path, Reason})
    end.


load(Theme, Size, Names) ->
    case lists:keyfind(Theme, 1, themes_and_dirs()) of
        {_, Dir} -> load_cursors(Dir, Size, Names);
        false    -> error({invalid_cursor_theme, Theme})
    end.


load_cursors(Dir, Size, Names) ->
    ThemeNames = [list_to_atom(Name) || Name <- cursors_names(Dir)],
    [load_cursor(Dir, Name, Size, ThemeNames) || Name <- Names].


load_cursor(Dir, Name, Size, Names) ->
    case lists:member(Name, Names) of
        true ->
            load_cursor(filename:join(Dir, atom_to_list(Name)), Name, Size);
        false ->
            error({invalid_cursor_name, Name})
    end.


load_cursor(File, Name, Size) ->
    case file:open(File, [raw, binary]) of
        {ok, IoDev} ->
            try
                {ImgSize, Imgs} = load_images(IoDev, Size),
                #wl_cursor{name=Name, size=ImgSize, images=Imgs}
            catch
                _:_ -> error({invalid_cursor_file, File})
            after
                file:close(IoDev)
            end;
        {error, Reason} ->
            error({load_cursor_error, File, Reason})
    end.


load_tocs(IoDev) ->
    {ok, <<"Xcur",?LU32(?FILE_HDR_LEN),?LU32(?FILE_VER),?LU32(NToc)>>}
        = file:read(IoDev, ?FILE_HDR_LEN),
    {ok, TocsBin} = file:read(IoDev, NToc * 12),
    [{Sz,Pos} || <<?LU32(?IMAGE_TYPE),?LU32(Sz),?LU32(Pos)>> <= TocsBin].


load_images(IoDev, Size) ->
    {ImgSize, ImgPos} = best_images(load_tocs(IoDev), Size),
    Imgs = lists:map(fun (Pos) -> load_image(IoDev, ImgSize, Pos) end, ImgPos),
    {ImgSize, Imgs}.


load_image(IoDev, Size, Pos) ->
    {ok,
     <<?LU32(?IMAGE_HDR_LEN),?LU32(?IMAGE_TYPE),?LU32(Size),?LU32(?IMAGE_VER)
       ,?LU32(W),?LU32(H),?LU32(Xhot),?LU32(Yhot),?LU32(Delay)>>
    } = file:pread(IoDev, Pos, ?IMAGE_HDR_LEN),

    true = check_image(W,H,Xhot,Yhot),
    DataPos = Pos + ?IMAGE_HDR_LEN,
    {ok, Data} = file:pread(IoDev, DataPos, W*H*4),
    #wl_cursor_image{ width=W
                    , height=H
                    , x_hot=Xhot
                    , y_hot=Yhot
                    , delay=Delay
                    , data=Data
                    }.


check_image(W,H,Xhot,Yhot) ->
        (W > 0) and (W < ?IMAGE_MAX_DIM)
    and (H > 0) and (H < ?IMAGE_MAX_DIM)
    and (Xhot =< W) and (Yhot =< H).


best_images([], Size) ->
    {Size, []};
best_images([{HSz, HPos} | Rest], Size) ->
    lists:foldr(fun (I,Acc) -> best_image(I,Acc,Size) end, {HSz, [HPos]}, Rest).


best_image({Sz,Pos}, {Sz, Acc}, _) ->
    {Sz, [Pos| Acc]};
best_image({Sz1,Pos}, {Sz2, Acc}, Size) ->
    case erlang:abs(Sz1-Size) < erlang:abs(Sz2-Size) of
        true  -> {Sz1, [Pos]};
        false -> {Sz2, Acc}
    end.


inherited_themes(Path) ->
    Index = filename:join(Path, "index.theme"),
    case filelib:is_regular(Index) of
        true ->
            case file:read_file(Index) of
                {ok, Bin} ->
                    Tokens = string:tokens(binary_to_list(Bin), "\n"),
                    inherited_theme(Path, Tokens);
                _ ->
                    []
            end;
        false ->
            []
    end.

inherited_theme(_Path, []) ->
    [];

inherited_theme(Path, ["Inherits" ++ Theme | _]) ->
    [Name | _] = string:tokens(Theme, "= ,;\t"),
    case theme_and_dir(filename:join(filename:dirname(Path), Name)) of
        []         -> [];
        [{_, Dir}] -> [{filename:basename(Path), Dir}]
    end;

inherited_theme(Path, [_ | Lines]) ->
    inherited_theme(Path, Lines).


expand_path("~/" ++ RelPath, SubPath) ->
    expand_path(os:getenv("HOME"), RelPath, SubPath);

expand_path(Path, SubPath) ->
    filename:join(Path, SubPath).

expand_path(false, _RelPath, _SubPath) ->
    error("HOME variable not set");

expand_path(Home, RelPath, SubPath) ->
    filename:join([Home, RelPath, SubPath]).


is_regular_or_symlink(File) ->
    case file:read_file_info(File) of
        {ok, #file_info{type=T}} -> T == regular orelse T == symlink;
        _                        -> false
    end.
